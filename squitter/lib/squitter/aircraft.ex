defmodule Squitter.Aircraft do
  use GenServer
  use Squitter.Messages

  require Logger
  use Bitwise
  import Squitter.Utils.Math

  alias Squitter.{AircraftLookup, SiteServer, Decoding.CPR}
  alias Squitter.Decoding.ExtSquitter.{GroundSpeed, AirSpeed}

  @air_pos_delta_max_s  5.0
  @warn_pos_delta_nm    50.0
  @timeout_period_s     60
  @clock_s              1

  def start_link(address) do
    GenServer.start_link(__MODULE__, [address], name: {:via, Registry, {Squitter.AircraftRegistry, address}})
  end

  def init([address]) do
    :pg2.join(:aircraft, self())

    reg =
      case AircraftLookup.get_registration(address) do
        {:ok, registration} -> registration
        {:error, _} -> ""
      end

    {:ok, country} = AircraftLookup.get_country(address)

    schedule_tick()

    {:ok, %{
      address: address,
      msgs: 0,
      category: %{set: :unknown, category: :unknown},
      country: country,
      altitude: 0,
      callsign: "",
      latlon: nil,
      last_even_position: nil,
      last_odd_position: nil,
      velocity_kt: 0,
      airspeed_type: nil,
      heading: nil,
      vr: 0,
      vr_dir: :na,
      vr_src: nil,
      registration: reg,
      squawk: "",
      distance: 0.0,
      position_history: [],
      timeout_enabled: true,
      last_received: System.monotonic_time(:seconds),
      age: 0}}
  end

  def handle_cast({:dispatch, msg}, state) do
    case handle_msg(msg, state) do
      {:ok, new_state} ->
        new_state = set_received(new_state)
        broadcast(:state_vector, build_state_vector(new_state), new_state)
        {:noreply, new_state}
      {:error, :invalid_crc} ->
        {:noreply, state}
    end
  end

  def handle_cast(:enable_age_timeout, state) do
    {:noreply, %{state | timeout_enabled: true}}
  end

  def handle_cast(:disable_age_timeout, state) do
    {:noreply, %{state | timeout_enabled: false}}
  end

  def handle_call(:state_vector, _from, state) do
    reply = build_state_vector(state)
    {:reply, {:ok, reply}, state}
  end

  defp handle_msg(%{crc: :invalid}, _state) do
    # Ignore messages with invalid CRC
    {:error, :invalid_crc}
  end

  defp handle_msg(%{tc: {:aircraft_id, _}, type_msg: %{aircraft_cat: cat, callsign: callsign}}, state) do
    {:ok, %{state | category: cat, callsign: callsign}}
  end

  # position with even flag
  defp handle_msg(%{tc: {alt_type, _}, time: time, type_msg: %{flag: flag, alt: alt} = pos}, state)
  when alt_type in [:airborne_pos_baro_alt, :airborne_pos_gnss_height] and band(flag, 1) == 0 do
    calculate_position(%{state | altitude: alt, last_even_position: {time, pos}})
  end

  # position with odd flag
  defp handle_msg(%{tc: {alt_type, _}, time: time, type_msg: %{flag: flag, alt: alt} = pos}, state)
  when alt_type in [:airborne_pos_baro_alt, :airborne_pos_gnss_height] and band(flag, 1) == 1 do
    calculate_position(%{state | altitude: alt, last_odd_position: {time, pos}})
  end

  defp handle_msg(%{tc: :no_position_info}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%{tc: :air_velocity, type_msg: %GroundSpeed{} = gs}, state) do
    {vel, head} = calculate_vector(gs)
    {vr, vrdir, vrsrc} = calculate_vertical_rate(gs)
    {:ok, %{state | velocity_kt: vel, heading: head, vr: vr, vr_dir: vrdir, vr_src: vrsrc}}
  end

  defp handle_msg(%{tc: :air_velocity, type_msg: %AirSpeed{} = msg}, state) do
    heading = if msg.sign_hdg do
      trunc(:erlang.float(msg.hdg) / 1024.0 * 360.0)
    else
      0
    end

    as_type = if msg.as_type, do: :true, else: :indicated
    {vr, vrdir, vrsrc} = calculate_vertical_rate(msg)

    {:ok, %{state | airspeed_type: as_type, velocity_kt: msg.as, heading: heading, vr: vr, vr_dir: vrdir, vr_src: vrsrc}}
  end

  defp handle_msg(%{tc: {:surface_pos, _}}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%AltitudeReply{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%IdentityReply{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%AllCallReply{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%ShortAcas{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%LongAcas{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%{tc: :aircraft_op_status, type_msg: _msg}, state) do
    # TODO
    # The Version Number for all 1090 MHz ADS-B Messages originating for each specific
    # ADS-B target is determined from the decoding of the Version Number subfield of the
    # Aircraft Operational Status Message. An ADS-B Version One (1) Receiving Subsystem
    # initially assumes that the messages conform to Version Zero (0) message formats, until or
    # unless received Version Number data indicates otherwise. The Version Number is
    # retained and associated with all messages from that specific target. This Version Number
    # is used for determining the applicable message formats to be applied for the decoding of
    # all 1090 MHz ADS-B Messages received from that target.
    {:ok, state}
  end

  defp handle_msg(%{tc: :target_state_status, type_msg: _msg}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%{tc: :aircraft_status, type_msg: _msg}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%{tc: :test_message, type_msg: _}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%{tc: :surface_sys_status, type_msg: _}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%{tc: :trajectory_change, type_msg: _}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(other, state) do
    Logger.warn "Unhandled msg in #{state.address}: #{inspect other}"
    {:ok, state}
  end

  defp build_state_vector(state) do
    state
    |> Map.take([:callsign, :registration, :squawk, :msgs, :category, :altitude, :velocity_kt,
      :heading, :vr, :vr_dir, :address, :age, :distance, :country])
    |> Map.put(:latlon, state.latlon)
  end

  def calculate_vector(msg) do
    v_we = if msg.sign_ew do
      -1 * (msg.v_ew - 1)
    else
      msg.v_ew - 1
    end

    v_sn = if msg.sign_ns do
      -1 * (msg.v_ns - 1)
    else
      msg.v_ns - 1
    end

    v = :math.sqrt(:math.pow(v_we, 2) + :math.pow(v_sn, 2))
    h = :math.atan2(v_we, v_sn) * (360/(2 * :math.pi))

    h = if h < 0, do: h + 360, else: h

    {trunc(v), trunc(h)}
  end

  def calculate_vertical_rate(msg) do
    vr = vr(msg)
    vr_dir = vr_dir(msg)
    vrsrc = vr_src(msg)
    {vr, vr_dir, vrsrc}
  end

  def vr(%{vr: vr}),
    do: if vr == 0, do: :na, else: (vr - 1) * 64
  def vr(_other),
    do: :error

  def vr_dir(%{vr: vr, sign_vr: sign_vr}) do
    cond do
      vr == 1 -> :none
      sign_vr == 0 -> :up
      sign_vr == 1 -> :down
      true -> :na
    end
  end
  def vr_dir(_other),
    do: :error

  def vr_src(%{vrsrc: vrsrc}),
    do: if vrsrc == 0, do: :geo, else: :baro
  def vr_src(_other),
    do: :error

  def calculate_position(%{last_even_position: even, last_odd_position: odd} = state) when is_nil(even) or is_nil(odd) do
    # We're missing one of the two messages so we can't calculate the position yet
    {:ok, state}
  end

  def calculate_position(%{last_even_position: {even_time, even}, last_odd_position: {odd_time, odd}} = state) do
    fflag? = odd_time > even_time

    with :ok <- check_air_pos_msg_delta(even_time, odd_time),
         {:ok, latlon} <- decode_airborne_cpr(even, odd, fflag?) do

      check_distance_from_last_pos(latlon, state.latlon, state)

      {:ok, site_location} = SiteServer.location()
      distance = calculate_gcd(latlon, site_location)

      pos_history =
        [latlon | state.position_history]
        |> Enum.reverse

      {:ok, %{state | latlon: latlon, distance: distance, position_history: pos_history}}
    else
      {:error, :air_pos_msg_delta} ->
        # More than X seconds between messages, clear the oldest one and bail out.
        {:ok, %{state | last_even_position: nil, last_odd_position: nil}}
      {:error, _} ->
        {:ok, state}
    end
  end

  def handle_info(:tick, state) do
    new_state = set_age(state)
    if state.timeout_enabled && timeout_expired?(new_state) do
      {:stop, {:shutdown, :timeout}, new_state}
    else
      if new_state.age > 0 do
        # If age is zero then we don't need to broadcast it
        broadcast(:age, %{address: state.address, age: new_state.age}, state)
      end
      schedule_tick()
      {:noreply, new_state}
    end
  end

  def terminate({:shutdown, :timeout}, state) do
    broadcast(:timeout, %{address: state.address}, state)
    Logger.debug "Aircraft #{state.address} timed out"
  end

  def terminate(reason, state) do
    broadcast(:terminated, %{address: state.address}, state)
    Logger.debug "Aircraft #{state.address} process terminated due to reason #{inspect reason}"
  end

  # Private helpers

  defp check_distance_from_last_pos(current_pos, previous_pos, state) do
    if !is_nil(previous_pos) do
      # Check distance from last position
      pos_delta = calculate_gcd(current_pos, previous_pos)
      if pos_delta > @warn_pos_delta_nm do
        Logger.warn "[#{state.address}:#{state.callsign}] Current position #{inspect current_pos} is over #{@warn_pos_delta_nm} NM from last position of #{inspect previous_pos} (#{pos_delta} NM)"
      end
    end
  end

  defp decode_airborne_cpr(even, odd, fflag?) do
    CPR.airborne_position(even.lat_cpr, even.lon_cpr, odd.lat_cpr, odd.lon_cpr, fflag?)
  end

  defp check_air_pos_msg_delta(even_time, odd_time) do
    receipt_delta_s = abs(odd_time - even_time) / 1_000_000
    if receipt_delta_s >= @air_pos_delta_max_s do
      {:error, :air_pos_msg_delta}
    else
      :ok
    end
  end

  defp broadcast(type, msg, state) when is_atom(type) do
    cond do
      type in [:timeout, :terminated] ->
        # Always broadcast timeouts and terminations
        Squitter.ReportCollector.report(type, msg)
      true ->
        # Everything else: broadcast only for aircraft which:
        # - we've received more than 1 message
        # - has position data
        # - is within the site range limit
        {:ok, range_limit} = SiteServer.range_limit()
        if state.msgs > 1 && length(state.position_history) > 0 && state.distance <= range_limit do
          Squitter.ReportCollector.report(type, msg)
        end
    end
  end

  defp timeout_expired?(%{age: age}) do
    age > @timeout_period_s
  end

  defp set_received(state) do
    %{state | msgs: state.msgs + 1, last_received: System.monotonic_time(:seconds)}
    |> set_age
  end

  defp set_age(%{last_received: last} = state) do
    now = System.monotonic_time(:seconds)
    %{state | age: now - last}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @clock_s * 1000)
  end
end
