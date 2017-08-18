defmodule Squitter.AircraftLookup do
  use GenServer
  require Logger

  defstruct [:n_number, :serial_number, :mfr_mdl_code, :eng_mfr_mdl, :year_mfr,
             :type_registrant, :name, :street, :street2, :city, :state, :zip_code,
             :region, :county, :country, :last_action_date, :cert_issue_date,
             :certification, :type_aircraft, :type_engine, :status_code, :mode_s_code,
             :fract_owner, :air_worth_date, :other_name_1, :other_name_2, :other_name_3,
             :other_name_4, :other_name_5, :expiration_date, :unique_id, :kit_mfr,
             :kit_model, :mode_s_code_hex]

  @priv_dir         :code.priv_dir(Mix.Project.config[:app])
  @faa_db_dir       Path.join(@priv_dir, "faa_db")
  @faa_db_zip       Path.join(@faa_db_dir, "ReleasableAircraft.zip")
  @faa_master_file  Path.join(@faa_db_dir, "MASTER.txt")
  @table            :aircraft_lookup

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_registration(address) do
    GenServer.call(__MODULE__, {:get_reg, address})
  end

  def get_country(address) do
    GenServer.call(__MODULE__, {:get_country, address})
  end

  def init(_) do
    {zip_time, _} = :timer.tc(&unzip_faa_db/0)
    Logger.debug "Unzipping the FAA database took #{trunc(zip_time/1000)} milliseconds"
    {load_time, _} = :timer.tc(&load_faa_db/0)
    Logger.debug "Loading the FAA database took #{trunc(load_time/1000)} milliseconds"
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

  def handle_call({:get_country, address}, _from, state) do
    {:reply, {:ok, lookup_country(address)}, state}
  end

  # Private

  defp transform_line(line) do
    split = String.split(line, [","])
    Enum.with_index(split)
    |> Enum.reduce(%__MODULE__{}, fn({field, index}, record) ->
         map_field(String.trim(field), index, record)
       end)
  end

  defp unzip_faa_db do
    Logger.debug("Unzipping FAA registration database")
    :zip.unzip(to_charlist(@faa_db_zip), [
                 :keep_old_files,
                 {:cwd, @faa_db_dir},
                 {:file_list, [@faa_master_file]}])
  end

  defp load_faa_db do
    Logger.debug("Loading FAA registration database into ETS")

    _ = :ets.new(@table, [:public, {:write_concurrency, true}, :named_table])

    File.stream!(@faa_master_file)
    |> Stream.drop(1)
    |> Flow.from_enumerable()
    |> Flow.each(fn(line) ->
         record = transform_line(line)
         true = :ets.insert_new(@table, {record.mode_s_code_hex, record})
       end)
    |> Flow.run
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

  defp lookup_country(address) do
    addr_int = String.to_integer(address, 16)

    cond do
      addr_int in 0x000000..0x003FFF -> "" # Unallocated
      addr_int in 0x004000..0x0043FF -> "Zimbabwe"
      addr_int in 0x006000..0x006FFF -> "Mozambique"
      addr_int in 0x008000..0x00FFFF -> "South Africa"
      addr_int in 0x010000..0x017FFF -> "Egypt"
      addr_int in 0x018000..0x01FFFF -> "Libya"
      addr_int in 0x020000..0x027FFF -> "Morocco"
      addr_int in 0x028000..0x02FFFF -> "Tunisia"
      addr_int in 0x030000..0x0303FF -> "Botswana"
      addr_int in 0x032000..0x032FFF -> "Burundi"
      addr_int in 0x034000..0x034FFF -> "Cameroon"
      addr_int in 0x035000..0x0353FF -> "Comoros"
      addr_int in 0x036000..0x036FFF -> "Congo"
      addr_int in 0x038000..0x038FFF -> "Côte d Ivoire"
      addr_int in 0x03E000..0x03EFFF -> "Gabon"
      addr_int in 0x040000..0x040FFF -> "Ethiopia"
      addr_int in 0x042000..0x042FFF -> "Equatorial Guinea"
      addr_int in 0x044000..0x044FFF -> "Ghana"
      addr_int in 0x046000..0x046FFF -> "Guinea"
      addr_int in 0x048000..0x0483FF -> "Guinea-Bissau"
      addr_int in 0x04A000..0x04A3FF -> "Lesotho"
      addr_int in 0x04C000..0x04CFFF -> "Kenya"
      addr_int in 0x050000..0x050FFF -> "Liberia"
      addr_int in 0x054000..0x054FFF -> "Madagascar"
      addr_int in 0x058000..0x058FFF -> "Malawi"
      addr_int in 0x05A000..0x05A3FF -> "Maldives"
      addr_int in 0x05C000..0x05CFFF -> "Mali"
      addr_int in 0x05E000..0x05E3FF -> "Mauritania"
      addr_int in 0x060000..0x0603FF -> "Mauritius"
      addr_int in 0x062000..0x062FFF -> "Niger"
      addr_int in 0x064000..0x064FFF -> "Nigeria"
      addr_int in 0x068000..0x068FFF -> "Uganda"
      addr_int in 0x06A000..0x06A3FF -> "Qatar"
      addr_int in 0x06C000..0x06CFFF -> "Central African Republic"
      addr_int in 0x06E000..0x06EFFF -> "Rwanda"
      addr_int in 0x070000..0x070FFF -> "Senegal"
      addr_int in 0x074000..0x0743FF -> "Seychelles"
      addr_int in 0x076000..0x0763FF -> "Sierra Leone"
      addr_int in 0x078000..0x078FFF -> "Somalia"
      addr_int in 0x07A000..0x07A3FF -> "Swaziland"
      addr_int in 0x07C000..0x07CFFF -> "Sudan"
      addr_int in 0x080000..0x080FFF -> "Tanzania"
      addr_int in 0x084000..0x084FFF -> "Chad"
      addr_int in 0x088000..0x088FFF -> "Togo"
      addr_int in 0x08A000..0x08AFFF -> "Zambia"
      addr_int in 0x08C000..0x08CFFF -> "DR Congo"
      addr_int in 0x090000..0x090FFF -> "Angola"
      addr_int in 0x094000..0x0943FF -> "Benin"
      addr_int in 0x096000..0x0963FF -> "Cape Verde"
      addr_int in 0x098000..0x0983FF -> "Djibouti"
      addr_int in 0x09A000..0x09AFFF -> "Gambia"
      addr_int in 0x09C000..0x09CFFF -> "Burkina Faso"
      addr_int in 0x09E000..0x09E3FF -> "Sao Tome"
      addr_int in 0x0A0000..0x0A7FFF -> "Algeria"
      addr_int in 0x0A8000..0x0A8FFF -> "Bahamas"
      addr_int in 0x0AA000..0x0AA3FF -> "Barbados"
      addr_int in 0x0AB000..0x0AB3FF -> "Belize"
      addr_int in 0x0AC000..0x0ACFFF -> "Colombia"
      addr_int in 0x0AE000..0x0AEFFF -> "Costa Rica"
      addr_int in 0x0B0000..0x0B0FFF -> "Cuba"
      addr_int in 0x0B2000..0x0B2FFF -> "El Salvador"
      addr_int in 0x0B4000..0x0B4FFF -> "Guatemala"
      addr_int in 0x0B6000..0x0B6FFF -> "Guyana"
      addr_int in 0x0B8000..0x0B8FFF -> "Haiti"
      addr_int in 0x0BA000..0x0BAFFF -> "Honduras"
      addr_int in 0x0BC000..0x0BC3FF -> "St.Vincent/Grenadines"
      addr_int in 0x0BE000..0x0BEFFF -> "Jamaica"
      addr_int in 0x0C0000..0x0C0FFF -> "Nicaragua"
      addr_int in 0x0C2000..0x0C2FFF -> "Panama"
      addr_int in 0x0C4000..0x0C4FFF -> "Dominican Republic"
      addr_int in 0x0C6000..0x0C6FFF -> "Trinidad/Tobago"
      addr_int in 0x0C8000..0x0C8FFF -> "Suriname"
      addr_int in 0x0CA000..0x0CA3FF -> "Antigua/Barbuda"
      addr_int in 0x0CC000..0x0CC3FF -> "Grenada"
      addr_int in 0x0D0000..0x0D7FFF -> "Mexico"
      addr_int in 0x0D8000..0x0DFFFF -> "Venezuela"
      addr_int in 0x100000..0x1FFFFF -> "Russia"
      addr_int in 0x200000..0x27FFFF -> "" # AFI
      addr_int in 0x201000..0x2013FF -> "Namibia"
      addr_int in 0x202000..0x2023FF -> "Eritrea"
      addr_int in 0x280000..0x2FFFFF -> "" # SAM
      addr_int in 0x300000..0x33FFFF -> "Italy"
      addr_int in 0x340000..0x37FFFF -> "Spain"
      addr_int in 0x380000..0x3BFFFF -> "France"
      addr_int in 0x3C0000..0x3FFFFF -> "Germany"
      addr_int in 0x400000..0x43FFFF -> "United Kingdom"
      addr_int in 0x440000..0x447FFF -> "Austria"
      addr_int in 0x448000..0x44FFFF -> "Belgium"
      addr_int in 0x450000..0x457FFF -> "Bulgaria"
      addr_int in 0x458000..0x45FFFF -> "Denmark"
      addr_int in 0x460000..0x467FFF -> "Finland"
      addr_int in 0x468000..0x46FFFF -> "Greece"
      addr_int in 0x470000..0x477FFF -> "Hungary"
      addr_int in 0x478000..0x47FFFF -> "Norway"
      addr_int in 0x480000..0x487FFF -> "Netherlands"
      addr_int in 0x488000..0x48FFFF -> "Poland"
      addr_int in 0x490000..0x497FFF -> "Portugal"
      addr_int in 0x498000..0x49FFFF -> "Czech Republic"
      addr_int in 0x4A0000..0x4A7FFF -> "Romania"
      addr_int in 0x4A8000..0x4AFFFF -> "Sweden"
      addr_int in 0x4B0000..0x4B7FFF -> "Switzerland"
      addr_int in 0x4B8000..0x4BFFFF -> "Turkey"
      addr_int in 0x4C0000..0x4C7FFF -> "Yugoslavia"
      addr_int in 0x4C8000..0x4C83FF -> "Cyprus"
      addr_int in 0x4CA000..0x4CAFFF -> "Ireland"
      addr_int in 0x4CC000..0x4CCFFF -> "Iceland"
      addr_int in 0x4D0000..0x4D03FF -> "Luxembourg"
      addr_int in 0x4D2000..0x4D23FF -> "Malta"
      addr_int in 0x4D4000..0x4D43FF -> "Monaco"
      addr_int in 0x500000..0x5003FF -> "San Marino"
      addr_int in 0x500000..0x5FFFFF -> "" # EUR/NAT
      addr_int in 0x501000..0x5013FF -> "Albania"
      addr_int in 0x501C00..0x501FFF -> "Croatia"
      addr_int in 0x502C00..0x502FFF -> "Latvia"
      addr_int in 0x503C00..0x503FFF -> "Lithuania"
      addr_int in 0x504C00..0x504FFF -> "Moldova"
      addr_int in 0x505C00..0x505FFF -> "Slovakia"
      addr_int in 0x506C00..0x506FFF -> "Slovenia"
      addr_int in 0x507C00..0x507FFF -> "Uzbekistan"
      addr_int in 0x508000..0x50FFFF -> "Ukraine"
      addr_int in 0x510000..0x5103FF -> "Belarus"
      addr_int in 0x511000..0x5113FF -> "Estonia"
      addr_int in 0x512000..0x5123FF -> "Macedonia"
      addr_int in 0x513000..0x5133FF -> "Bosnia/Herzegovina"
      addr_int in 0x514000..0x5143FF -> "Georgia"
      addr_int in 0x515000..0x5153FF -> "Tajikistan"
      addr_int in 0x600000..0x6003FF -> "Armenia"
      addr_int in 0x600000..0x67FFFF -> "" # MID
      addr_int in 0x600800..0x600BFF -> "Azerbaijan"
      addr_int in 0x601000..0x6013FF -> "Kyrgyzstan"
      addr_int in 0x601800..0x601BFF -> "Turkmenistan"
      addr_int in 0x680000..0x6FFFFF -> "" # Asia
      addr_int in 0x680000..0x6803FF -> "Bhutan"
      addr_int in 0x681000..0x6813FF -> "Micronesia"
      addr_int in 0x682000..0x6823FF -> "Mongolia"
      addr_int in 0x683000..0x6833FF -> "Kazakhstan"
      addr_int in 0x684000..0x6843FF -> "Palau"
      addr_int in 0x700000..0x700FFF -> "Afghanistan"
      addr_int in 0x702000..0x702FFF -> "Bangladesh"
      addr_int in 0x704000..0x704FFF -> "Myanmar"
      addr_int in 0x706000..0x706FFF -> "Kuwait"
      addr_int in 0x708000..0x708FFF -> "Laos"
      addr_int in 0x70A000..0x70AFFF -> "Nepal"
      addr_int in 0x70C000..0x70C3FF -> "Oman"
      addr_int in 0x70E000..0x70EFFF -> "Cambodia"
      addr_int in 0x710000..0x717FFF -> "Saudi Arabia"
      addr_int in 0x718000..0x71FFFF -> "South Korea"
      addr_int in 0x720000..0x727FFF -> "North Korea"
      addr_int in 0x728000..0x72FFFF -> "Iraq"
      addr_int in 0x730000..0x737FFF -> "Iran"
      addr_int in 0x738000..0x73FFFF -> "Israel"
      addr_int in 0x740000..0x747FFF -> "Jordan"
      addr_int in 0x748000..0x74FFFF -> "Lebanon"
      addr_int in 0x750000..0x757FFF -> "Malaysia"
      addr_int in 0x758000..0x75FFFF -> "Philippines"
      addr_int in 0x760000..0x767FFF -> "Pakistan"
      addr_int in 0x768000..0x76FFFF -> "Singapore"
      addr_int in 0x770000..0x777FFF -> "Sri Lanka"
      addr_int in 0x778000..0x77FFFF -> "Syria"
      addr_int in 0x780000..0x7BFFFF -> "China"
      addr_int in 0x7C0000..0x7FFFFF -> "Australia"
      addr_int in 0x800000..0x83FFFF -> "India"
      addr_int in 0x840000..0x87FFFF -> "Japan"
      addr_int in 0x880000..0x887FFF -> "Thailand"
      addr_int in 0x888000..0x88FFFF -> "Viet Nam"
      addr_int in 0x890000..0x890FFF -> "Yemen"
      addr_int in 0x894000..0x894FFF -> "Bahrain"
      addr_int in 0x895000..0x8953FF -> "Brunei"
      addr_int in 0x896000..0x896FFF -> "United Arab Emirates"
      addr_int in 0x897000..0x8973FF -> "Solomon Islands"
      addr_int in 0x898000..0x898FFF -> "Papua New Guinea"
      addr_int in 0x899000..0x8993FF -> "Taiwan"
      addr_int in 0x8A0000..0x8A7FFF -> "Indonesia"
      addr_int in 0x900000..0x9FFFFF -> "" # NAM/PAC
      addr_int in 0x900000..0x9003FF -> "Marshall Islands"
      addr_int in 0x901000..0x9013FF -> "Cook Islands"
      addr_int in 0x902000..0x9023FF -> "Samoa"
      addr_int in 0xA00000..0xAFFFFF -> "United States"
      addr_int in 0xB00000..0xBFFFFF -> "" # Reserved
      addr_int in 0xC00000..0xC3FFFF -> "Canada"
      addr_int in 0xC80000..0xC87FFF -> "New Zealand"
      addr_int in 0xC88000..0xC88FFF -> "Fiji"
      addr_int in 0xC8A000..0xC8A3FF -> "Nauru"
      addr_int in 0xC8C000..0xC8C3FF -> "Saint Lucia"
      addr_int in 0xC8D000..0xC8D3FF -> "Tonga"
      addr_int in 0xC8E000..0xC8E3FF -> "Kiribati"
      addr_int in 0xC90000..0xC903FF -> "Vanuatu"
      addr_int in 0xD00000..0xDFFFFF -> "" # Reserved
      addr_int in 0xE00000..0xE3FFFF -> "Argentina"
      addr_int in 0xE40000..0xE7FFFF -> "Brazil"
      addr_int in 0xE80000..0xE80FFF -> "Chile"
      addr_int in 0xE84000..0xE84FFF -> "Ecuador"
      addr_int in 0xE88000..0xE88FFF -> "Paraguay"
      addr_int in 0xE8C000..0xE8CFFF -> "Peru"
      addr_int in 0xE90000..0xE90FFF -> "Uruguay"
      addr_int in 0xE94000..0xE94FFF -> "Bolivia"
      addr_int in 0xEC0000..0xEFFFFF -> "" # CAR
      addr_int in 0xF00000..0xF07FFF -> "" # ICAO 1
      addr_int in 0xF00000..0xFFFFFF -> "" # Reserved
      addr_int in 0xF09000..0xF093FF -> "" # ICAO 2
      true -> ""
    end
  end
end
