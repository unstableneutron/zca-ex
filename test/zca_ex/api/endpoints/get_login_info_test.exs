defmodule ZcaEx.Api.Endpoints.GetLoginInfoTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.GetLoginInfo
  alias ZcaEx.Error

  describe "normalize_error/1" do
    test "wraps HTTP status into api error" do
      error = GetLoginInfo.normalize_error({:ok, %{status: 401}})
      assert %Error{category: :api, code: 401} = error
    end

    test "wraps client errors into network error" do
      error = GetLoginInfo.normalize_error({:error, :timeout})
      assert %Error{category: :network, retryable?: true} = error
    end
  end
end
