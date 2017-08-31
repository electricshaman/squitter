defmodule Squitter.MasterLookup do
  use GenServer
  require Logger

  defstruct [:n_number, :serial_number, :mfr_mdl_code, :eng_mfr_mdl, :year_mfr,
             :type_registrant, :name, :street, :street2, :city, :state, :zip_code,
             :region, :county, :country, :last_action_date, :cert_issue_date,
             :certification, :type_aircraft, :type_engine, :status_code, :mode_s_code,
             :fract_owner, :air_worth_date, :other_name_1, :other_name_2, :other_name_3,
             :other_name_4, :other_name_5, :expiration_date, :unique_id, :kit_mfr,
             :kit_model, :mode_s_code_hex]

  @app              Mix.Project.config[:app]
  @master_table     :faa_master_lookup
  @master_filename  "MASTER.txt"
  @priv_sub_dir     "faa_db"
  @zip_filename     "ReleasableAircraft.zip"

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(address) do
    GenServer.call(__MODULE__, {:get, address})
  end

  def init(_) do
    _ = :ets.new(@master_table, [:public, {:write_concurrency, true}, :named_table])

    parent = self()
    Task.start_link(fn ->
      {zip_time, _} =
        :timer.tc(fn ->
          unzip_faa_db(faa_zip_file_path(), faa_dir(), [to_charlist(@master_filename)])
        end)

      {load_time, _} =
        :timer.tc(fn ->
          load_faa_db(@master_table)
        end)

      send(parent, {:loaded, zip_time, load_time})
    end)

    {:ok, false}
  end

  def handle_info({:loaded, zip_time, load_time}, false) do
    Logger.debug "Unzipping the FAA database took #{trunc(zip_time/1000)} milliseconds"
    Logger.debug "Loading the FAA database took #{trunc(load_time/1000)} milliseconds"
    {:noreply, true}
  end

  def handle_call({:get, _address}, _from, false),
    do: {:reply, {:error, :not_available}, false}
  def handle_call({:get, address}, _from, true) do
    reply =
      case :ets.lookup(@master_table, address) do
        [] ->
          {:error, :address_not_found}
        [{^address, record}] ->
          {:ok, record}
      end
    {:reply, reply, true}
  end

  def unzip_faa_db(zip_file_path, output_dir, file_list) do
    Logger.debug("Unzipping FAA registration database")
    :zip.unzip(to_charlist(zip_file_path), [
                 :keep_old_files,
                 {:cwd, output_dir},
                 {:file_list, file_list}])
  end

  def load_faa_db(ets_table) do
    Logger.debug("Loading FAA registration database into ETS")

    File.stream!(faa_master_file_path())
    |> Stream.drop(1)
    |> Flow.from_enumerable()
    |> Flow.each(fn(line) ->
         record = transform_line(line)
         true = :ets.insert_new(ets_table, {record.mode_s_code_hex, record})
       end)
    |> Flow.run
  end

  def priv_dir,
    do: :code.priv_dir(@app)

  def faa_dir,
    do: Path.join(priv_dir(), @priv_sub_dir)

  def faa_zip_file_path,
    do: Path.join(faa_dir(), @zip_filename)

  def faa_master_file_path,
    do: Path.join(faa_dir(), @master_filename)

  # Private

  defp transform_line(line) do
    split = String.split(line, [","])
    Enum.with_index(split)
    |> Enum.reduce(%__MODULE__{}, fn({field, index}, record) ->
         map_field(String.trim(field), index, record)
       end)
  end

  defp map_field(field, index, record) do
    key = case index do
      0 -> :n_number
      1 -> :serial_number
      2 -> :mfr_mdl_code
      3 -> :eng_mfr_mdl
      4 -> :year_mfr
      5 -> :type_registrant
      6 -> :name
      7 -> :street
      8 -> :street2
      9 -> :city
      10 -> :state
      11 -> :zip_code
      12 -> :region
      13 -> :county
      14 -> :country
      15 -> :last_action_date
      16 -> :cert_issue_date
      17 -> :certification
      18 -> :type_aircraft
      19 -> :type_engine
      20 -> :status_code
      21 -> :mode_s_code
      22 -> :fract_owner
      23 -> :air_worth_date
      24 -> :other_name_1
      25 -> :other_name_2
      26 -> :other_name_3
      27 -> :other_name_4
      28 -> :other_name_5
      29 -> :expiration_date
      30 -> :unique_id
      31 -> :kit_mfr
      32 -> :kit_model
      33 -> :mode_s_code_hex
      _ -> :unknown
    end

    if key == :unknown,
      do: record,
      else: Map.put(record, key, field)
  end
end
