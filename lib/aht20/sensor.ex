defmodule AHT20.Sensor do
  @moduledoc false

  use Bitwise, only_operators: true

  @default_bus_name "i2c-1"
  @default_bus_address 0x38

  @aht20_cmd_initialize 0xBE
  @aht20_cmd_trigger_measurement 0xAC
  @aht20_cmd_soft_reset 0xBA
  @aht20_cmd_read_state 0x71

  @type bus_name :: AHT20.Transport.bus_name()
  @type bus_address :: AHT20.Transport.address()
  @type transport :: pid()

  @typedoc """
  The configuration options.
  """

  @type config :: [{:bus_name, bus_name} | {:bus_address, bus_address}]

  defstruct [:transport, :bus_address]

  @typedoc """
  Represents the connection to the sensor.
  """
  @type t :: %__MODULE__{
          bus_address: bus_address,
          transport: pid
        }

  @doc """
  Connects to the sensor.
  For more info. please refer to the data sheet (section 5.4).
  """
  @spec start(config) :: {:ok, t} | {:error, any}
  def start(config \\ []) do
    bus_name = config[:bus_name] || @default_bus_name
    bus_address = config[:bus_address] || @default_bus_address

    with {:ok, transport} <- AHT20.Transport.I2C.start_link(bus_name: bus_name, bus_address: bus_address),
         :ok <- Process.sleep(40),
         :ok <- AHT20.Transport.I2C.write(transport, [@aht20_cmd_soft_reset]),
         :ok <- Process.sleep(20),
         :ok <- AHT20.Transport.I2C.write(transport, [@aht20_cmd_initialize, <<0x08, 0x00>>]) do
      {:ok, __struct__(transport: transport, bus_address: bus_address)}
    end
  end

  @doc """
  Triggers the sensor to read temperature and humidity.
  """
  @spec read_data(t) :: {:ok, <<_::56>>} | {:error, any}
  def read_data(%{transport: transport}) do
    with :ok <- AHT20.Transport.I2C.write(transport, [@aht20_cmd_trigger_measurement, <<0x33, 0x00>>]),
         :ok <- Process.sleep(75) do
      AHT20.Transport.I2C.read(transport, 7)
    end
  end

  @doc """
  Obtains the sensor status byte.
  For more info. please refer to the data sheet (section 5.3).
  """
  @spec read_state(t) :: {:ok, <<_::8>>} | {:error, any}
  def read_state(%{transport: transport}) do
    AHT20.Transport.I2C.write_read(transport, @aht20_cmd_read_state, 1)
  end
end
