defmodule ZcaEx.Account.Session do
  @moduledoc "Session state for an authenticated Zalo account"

  @type t :: %__MODULE__{
          uid: String.t(),
          secret_key: String.t(),
          zpw_service_map: map(),
          ws_endpoints: [String.t()],
          api_type: integer(),
          api_version: integer(),
          settings: map() | nil,
          login_info: map() | nil,
          extra_ver: map() | nil
        }

  defstruct [
    :uid,
    :secret_key,
    :zpw_service_map,
    :settings,
    :login_info,
    :extra_ver,
    ws_endpoints: [],
    api_type: 30,
    api_version: 645
  ]

  @spec from_login_response(map()) :: t()
  def from_login_response(data) when is_map(data) do
    %__MODULE__{
      uid: to_string(get_in(data, ["uid"]) || get_in(data, [:uid])),
      secret_key: get_in(data, ["zpw_enk"]) || get_in(data, [:zpw_enk]),
      zpw_service_map: get_in(data, ["zpw_service_map_v3"]) || get_in(data, [:zpw_service_map_v3]) || %{},
      settings: get_in(data, ["settings"]) || get_in(data, [:settings]),
      login_info: extract_login_info(data),
      extra_ver: get_in(data, ["extra_ver"]) || get_in(data, [:extra_ver])
    }
  end

  defp extract_login_info(data) do
    %{
      "isNewAccount" => get_in(data, ["isNewAccount"]) || get_in(data, [:isNewAccount]),
      "avatar" => get_in(data, ["avatar"]) || get_in(data, [:avatar]),
      "displayName" => get_in(data, ["displayName"]) || get_in(data, [:displayName]),
      "phoneNumber" => get_in(data, ["phoneNumber"]) || get_in(data, [:phoneNumber])
    }
  end
end
