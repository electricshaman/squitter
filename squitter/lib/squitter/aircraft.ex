defmodule Squitter.Aircraft do
  use GenServer
  use Squitter.Messages

  require Logger
  use Bitwise
  import Squitter.Utils.Math

  alias Squitter.{MasterLookup, Site, Decoding.CPR, StateReport, StatsTracker}
  alias Squitter.Decoding.ExtSquitter.{GroundSpeed, AirSpeed}

  @air_pos_time_delta_max_s   5.0
  @air_pos_dist_delta_max_nm  100.0
  @timeout_period_s           60
  @clock_s                    1
  @master_attempts            10
  @master_attempt_interval    15000

  def start_link(address) do
    GenServer.start_link(__MODULE__, [address], name: {:via, Registry, {Squitter.AircraftRegistry, address}})
  end

  def init([address]) do
    country = Squitter.CountryLookup.get(address)

    schedule_tick()

    send(self(), {:try_master, 1})

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
      vr_src: nil,
      squawk: "",
      distance: 0.0,
      position_history: [],
      timeout_enabled: true,
      master: %{},
      last_received: System.monotonic_time(:seconds),
      age: 0}}
  end

  def handle_cast({:dispatch, msg}, state) do
    case handle_msg(msg, state) do
      {:ok, new_state} ->
        new_state = set_received(new_state)
        new_state
        |> build_view
        |> report
        {:noreply, new_state}
      {:error, _} ->
        {:noreply, state}
    end
  end

  defp handle_msg(%{df: df, crc: :invalid}, _state) do
    # Ignore messages with invalid CRC
    StatsTracker.count([:crc_failed, :df, df])
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
    {:ok, %{state | velocity_kt: gs.velocity_kt, heading: gs.heading, vr: gs.vert_rate, vr_src: gs.vert_rate_src}}
  end

  defp handle_msg(%{tc: :air_velocity, type_msg: %AirSpeed{} = as}, state) do
    {:ok, %{state | airspeed_type: as.airspeed_type, velocity_kt: as.velocity_kt, heading: as.heading, vr: as.vert_rate, vr_src: as.vert_rate_src}}
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

  defp handle_msg(%CommBAltitudeReply{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%CommBIdentityReply{}, state) do
    # TODO
    {:ok, state}
  end

  defp handle_msg(%CommDElm{}, state) do
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

  # Msg handlers when data's coming from ADSBExchange (demo)
  defp handle_msg(%{"Call" => callsign}, state) do
    {:ok, %{state | callsign: callsign}}
  end
  defp handle_msg(%{"Lat" => lat, "Long" => lon, "Alt" => alt, "Spd" => spd, "Trak" => trak}, state) do
    latlon = [lat, lon]
    position = latlon ++ [alt]

    pos_history = [position|state.position_history]

    {:ok, site_location} = Site.location()
    distance = calculate_gcd(latlon, site_location)

    {:ok, %{state | altitude: alt, velocity_kt: spd, distance: distance, latlon: latlon, position_history: pos_history, heading: trak}}
  end
  defp handle_msg(%{"Icao" => _address} = other, state) do
    # Ignore
    {:ok, state}
  end

  defp handle_msg(other, state) do
    Logger.warn "Unhandled msg in #{state.address}: #{inspect other}"
    {:ok, state}
  end

  defp build_view(state) do
    state
    |> Map.take([:callsign, :registration, :squawk, :msgs, :category, :altitude, :velocity_kt,
      :heading, :vr, :address, :age, :distance, :country])
    |> Map.put(:position_history, Enum.reverse(state.position_history)) # Reverse so most recent is at the end
    |> Map.put(:latlon, state.latlon)
    |> Map.put(:registration, case state.master do
         %MasterLookup{n_number: n_number} -> "N" <> n_number
         %{} -> ""
       end)
  end

  def calculate_position(%{last_even_position: even, last_odd_position: odd} = state) when is_nil(even) or is_nil(odd) do
    # We're missing one of the two messages so we can't calculate the position yet
    {:ok, state}
  end

  def calculate_position(%{last_even_position: {even_time, even}, last_odd_position: {odd_time, odd}} = state) do
    fflag? = odd_time > even_time

    with :ok <- check_air_pos_time_delta(even_time, odd_time),
         {:ok, latlon} <- decode_airborne_cpr(even, odd, fflag?),
         :ok <- check_air_pos_dist(latlon, state.latlon) do

      {:ok, site_location} = Site.location()
      distance = calculate_gcd(latlon, site_location)

      position = latlon ++ [state.altitude]

      # Most recent position is the head of the list
      pos_history = [position|state.position_history]

      {:ok, %{state | latlon: latlon, distance: distance, position_history: pos_history}}
    else
      {:error, :air_pos_time_delta} ->
        # More than X seconds between messages, clear the oldest one and bail out.
        {:ok, %{state | last_even_position: nil, last_odd_position: nil}}
      {:error, {:air_pos_dist, position, dist}} ->
        Logger.warn "[#{state.address}:#{state.callsign}] Skipping current position #{inspect position}: over #{@air_pos_dist_delta_max_nm} NM from last position of #{inspect state.latlon} (#{dist} NM)"
        {:ok, state}
      {:error, _} ->
        {:ok, state}
    end
  end

  def handle_info(:tick, state) do
    new_state = set_age(state)
    if state.timeout_enabled && timeout_expired?(new_state) do
      {:stop, {:shutdown, :timeout}, new_state}
    else
      new_state
      |> build_view
      |> report
      schedule_tick()
      {:noreply, new_state}
    end
  end

  def handle_info({:try_master, attempt}, state) do
    case MasterLookup.get(state.address) do
      {:ok, master} -> {:noreply, %{state | master: master}}
      {:error, _} ->
        if attempt < @master_attempts do
          next_attempt = attempt + 1
          Logger.debug "Scheduling attempt #{next_attempt} to retrieve master data for #{state.address}"
          Process.send_after(self(), {:try_master, next_attempt}, @master_attempt_interval)
        else
          Logger.debug "Giving up trying to get master data for #{state.address}"
        end
        {:noreply, state}
    end
  end

  def terminate({:shutdown, :timeout}, state) do
    Logger.debug "Aircraft #{state.address} timed out"
  end

  def terminate(reason, state) do
    Logger.debug "Aircraft #{state.address} process terminated due to reason #{inspect reason}"
  end

  # Private helpers

  defp check_air_pos_dist(_current_pos, nil), do: :ok
  defp check_air_pos_dist(current_pos, previous_pos) do
    dist_delta = calculate_gcd(current_pos, previous_pos)

    # Check distance from site and from last good position is within range
    {:ok, site_location} = Site.location()
    {:ok, range_limit} = Site.range_limit()

    dist_from_site = calculate_gcd(current_pos, site_location)

    if dist_delta > @air_pos_dist_delta_max_nm && dist_from_site > range_limit do
      {:error, {:air_pos_dist, current_pos, dist_delta}}
    else
      :ok
    end
  end

  defp decode_airborne_cpr(even, odd, fflag?) do
    CPR.airborne_position(even.lat_cpr, even.lon_cpr, odd.lat_cpr, odd.lon_cpr, fflag?)
  end

  defp check_air_pos_time_delta(even_time, odd_time) do
    receipt_delta_s = abs(odd_time - even_time) / 1_000_000
    if receipt_delta_s >= @air_pos_time_delta_max_s do
      {:error, :air_pos_time_delta}
    else
      :ok
    end
  end

  defp report(report) do
    # Only update the state report for aircraft where:
    # - We've received more than 1 message
    # - We have position data
    # - The latest position is within the site range limit
    {:ok, range_limit} = Site.range_limit()
    # TODO: Figure out what to do about aircraft that cross over the range threshold
    if report.msgs > 1 && length(report.position_history) > 0 && report.distance <= range_limit do
      StateReport.state_changed(report.address, report)
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
