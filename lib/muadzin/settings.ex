defmodule Muadzin.Settings do
  @moduledoc """
  Manages application settings for prayer time calculations.
  Settings are stored persistently in /data/settings.json on target devices.
  """

  @default_latitude 35.67220046284479
  @default_longitude 139.90246423845966
  @default_timezone "Asia/Tokyo"
  @settings_file "/data/settings.json"

  def get_latitude do
    get_all().latitude
  end

  def get_longitude do
    get_all().longitude
  end

  def get_timezone do
    get_all().timezone
  end

  def update_location(latitude, longitude, timezone) do
    with {:ok, lat} <- parse_float(latitude),
         {:ok, lon} <- parse_float(longitude),
         :ok <- validate_latitude(lat),
         :ok <- validate_longitude(lon),
         :ok <- validate_timezone(timezone) do
      settings = %{latitude: lat, longitude: lon, timezone: timezone}

      # Save to file
      case save_to_file(settings) do
        :ok ->
          # Notify scheduler to recalculate
          Phoenix.PubSub.broadcast(
            Muadzin.PubSub,
            "settings",
            {:settings_updated, settings}
          )

          {:ok, settings}

        {:error, reason} ->
          {:error, "Failed to save settings: #{inspect(reason)}"}
      end
    end
  end

  def get_all do
    case load_from_file() do
      {:ok, settings} -> settings
      {:error, _} -> default_settings()
    end
  end

  defp default_settings do
    %{
      latitude: @default_latitude,
      longitude: @default_longitude,
      timezone: @default_timezone
    }
  end

  defp save_to_file(settings) do
    json = Jason.encode!(settings)

    # Create /data directory if it doesn't exist (on host for testing)
    settings_dir = Path.dirname(@settings_file)
    unless File.exists?(settings_dir) do
      File.mkdir_p(settings_dir)
    end

    case File.write(@settings_file, json) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_from_file do
    case File.read(@settings_file) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, settings} -> {:ok, settings}
          {:error, reason} -> {:error, reason}
        end

      {:error, :enoent} ->
        # File doesn't exist, use defaults
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_float(value) when is_float(value), do: {:ok, value}
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "Invalid number format"}
    end
  end
  defp parse_float(_), do: {:error, "Invalid number format"}

  defp validate_latitude(lat) when lat >= -90 and lat <= 90, do: :ok
  defp validate_latitude(_), do: {:error, "Latitude must be between -90 and 90"}

  defp validate_longitude(lon) when lon >= -180 and lon <= 180, do: :ok
  defp validate_longitude(_), do: {:error, "Longitude must be between -180 and 180"}

  defp validate_timezone(tz) when is_binary(tz) and byte_size(tz) > 0 do
    # Basic validation - check if timezone exists in tzdata
    case Timex.Timezone.get(tz) do
      %Timex.TimezoneInfo{} -> :ok
      _ -> {:error, "Invalid timezone"}
    end
  end
  defp validate_timezone(_), do: {:error, "Timezone must be a non-empty string"}
end
