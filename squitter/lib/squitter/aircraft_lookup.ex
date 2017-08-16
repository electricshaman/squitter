defmodule Squitter.AircraftLookup do
  use GenServer

  defstruct [:n_number, :serial_number, :mfr_mdl_code, :eng_mfr_mdl, :year_mfr,
             :type_registrant, :name, :street, :street2, :city, :state, :zip_code,
             :region, :county, :country, :last_action_date, :cert_issue_date,
             :certification, :type_aircraft, :type_engine, :status_code, :mode_s_code,
             :fract_owner, :air_worth_date, :other_name_1, :other_name_2, :other_name_3,
             :other_name_4, :other_name_5, :expiration_date, :unique_id, :kit_mfr,
             :kit_model, :mode_s_code_hex]

  @app Mix.Project.config[:app]
  @faa_master_file Path.join("faa_db", "MASTER.txt")
  @table :aircraft_lookup

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_registration(address) do
    GenServer.call(__MODULE__, {:get_reg, address})
  end

  def init(_) do
    _ = :ets.new(@table, [:private, :named_table])
    master_file_path = Path.join(:code.priv_dir(@app), @faa_master_file)
    File.stream!(master_file_path)
    |> Stream.drop(1)
    |> Stream.each(fn(line) ->
         record = transform_line(line)
         true = :ets.insert_new(@table, {record.mode_s_code_hex, record})
       end)
    |> Stream.run

    {:ok, %{}}
  end

  def handle_call({:get_reg, address}, _from, state) do
    reply =
      case :ets.lookup(@table, address) do
        [] ->
          {:error, :address_not_found}
        [{^address, record}] ->
          {:ok, "N" <> record.n_number}
      end
    {:reply, reply, state}
  end

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
