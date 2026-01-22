defmodule ZcaEx.Api.Endpoints.CreateNoteTest do
  use ExUnit.Case, async: true

  alias ZcaEx.Api.Endpoints.CreateNote
  alias ZcaEx.Account.{Session, Credentials}

  @secret_key Base.encode64(:crypto.strong_rand_bytes(32))

  setup do
    session = %Session{
      uid: "123456",
      secret_key: @secret_key,
      zpw_service_map: %{
        "group_board" => ["https://board.zalo.me"]
      },
      api_type: 30,
      api_version: 645
    }

    {:ok, credentials} =
      Credentials.new(
        imei: "test-imei-12345",
        user_agent: "Mozilla/5.0 Test",
        cookies: [%{"name" => "test", "value" => "cookie"}],
        language: "vi"
      )

    {:ok, session: session, credentials: credentials}
  end

  describe "build_params/4" do
    test "builds correct params with pin? = false", %{credentials: credentials} do
      assert {:ok, params} = CreateNote.build_params("group123", "Test Note", false, credentials)

      assert params.grid == "group123"
      assert params.type == 0
      assert params.color == -16_777_216
      assert params.emoji == ""
      assert params.startTime == -1
      assert params.duration == -1
      assert params.params == ~s({"title":"Test Note"})
      assert params.repeat == 0
      assert params.src == 1
      assert params.imei == "test-imei-12345"
      assert params.pinAct == 0
    end

    test "builds correct params with pin? = true", %{credentials: credentials} do
      assert {:ok, params} = CreateNote.build_params("group123", "Pinned Note", true, credentials)

      assert params.pinAct == 1
      assert params.params == ~s({"title":"Pinned Note"})
    end

    test "encodes title with special characters", %{credentials: credentials} do
      assert {:ok, params} =
               CreateNote.build_params(
                 "group123",
                 "Note with \"quotes\" & symbols",
                 false,
                 credentials
               )

      assert params.params == ~s({"title":"Note with \\"quotes\\" & symbols"})
    end
  end

  describe "build_url/1" do
    test "builds correct URL with session params", %{session: session} do
      url = CreateNote.build_url(session)

      assert url =~ "https://board.zalo.me/api/board/topic/createv2"
      assert url =~ "zpw_ver=645"
      assert url =~ "zpw_type=30"
    end

    test "handles service URL as string", %{session: session} do
      session = %{session | zpw_service_map: %{"group_board" => "https://board2.zalo.me"}}
      url = CreateNote.build_url(session)

      assert url =~ "https://board2.zalo.me/api/board/topic/createv2"
    end
  end

  describe "transform_note_detail/1" do
    test "parses params JSON string" do
      data = %{"id" => "123", "params" => ~s({"title":"My Note","description":"test"})}
      result = CreateNote.transform_note_detail(data)

      assert result[:params] == %{"title" => "My Note", "description" => "test"}
      assert result["id"] == "123"
    end

    test "handles params as atom key" do
      data = %{id: "123", params: ~s({"title":"My Note"})}
      result = CreateNote.transform_note_detail(data)

      assert result[:params] == %{"title" => "My Note"}
    end

    test "keeps invalid JSON as string" do
      data = %{"params" => "not valid json {"}
      result = CreateNote.transform_note_detail(data)

      assert result[:params] == "not valid json {"
    end

    test "handles params already as map" do
      data = %{"params" => %{"title" => "Already Parsed"}}
      result = CreateNote.transform_note_detail(data)

      assert result[:params] == %{"title" => "Already Parsed"}
    end

    test "handles nil params" do
      data = %{"id" => "123"}
      result = CreateNote.transform_note_detail(data)

      assert result[:params] == nil
    end

    test "handles empty params string" do
      data = %{"params" => ""}
      result = CreateNote.transform_note_detail(data)

      assert result[:params] == ""
    end
  end

  describe "create/5 validation" do
    test "returns error for empty group_id", %{session: session, credentials: credentials} do
      result = CreateNote.create("", "Title", false, session, credentials)

      assert {:error, error} = result
      assert error.message == "group_id must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil group_id", %{session: session, credentials: credentials} do
      result = CreateNote.create(nil, "Title", false, session, credentials)

      assert {:error, error} = result
      assert error.message == "group_id must be a non-empty string"
    end

    test "returns error for non-string group_id", %{session: session, credentials: credentials} do
      result = CreateNote.create(123, "Title", false, session, credentials)

      assert {:error, error} = result
      assert error.message == "group_id must be a non-empty string"
    end

    test "returns error for empty title", %{session: session, credentials: credentials} do
      result = CreateNote.create("group123", "", false, session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
      assert error.code == :invalid_input
    end

    test "returns error for nil title", %{session: session, credentials: credentials} do
      result = CreateNote.create("group123", nil, false, session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
    end

    test "returns error for non-string title", %{session: session, credentials: credentials} do
      result = CreateNote.create("group123", 456, false, session, credentials)

      assert {:error, error} = result
      assert error.message == "title must be a non-empty string"
    end

    test "returns error for non-boolean pin?", %{session: session, credentials: credentials} do
      result = CreateNote.create("group123", "Title", "yes", session, credentials)

      assert {:error, error} = result
      assert error.message == "pin? must be a boolean"
      assert error.code == :invalid_input
    end

    test "returns error for nil pin?", %{session: session, credentials: credentials} do
      result = CreateNote.create("group123", "Title", nil, session, credentials)

      assert {:error, error} = result
      assert error.message == "pin? must be a boolean"
    end

    test "raises for missing service URL", %{session: session, credentials: credentials} do
      session_no_service = %{session | zpw_service_map: %{}}

      assert_raise RuntimeError, ~r/group_board service URL not found/, fn ->
        CreateNote.create("group123", "Title", false, session_no_service, credentials)
      end
    end
  end
end
