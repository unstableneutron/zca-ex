defmodule ZcaEx.WS.ControlParserTest do
  use ExUnit.Case, async: true

  alias ZcaEx.WS.ControlParser

  describe "parse/1" do
    test "returns empty list for payload without controls" do
      assert [] = ControlParser.parse(%{})
      assert [] = ControlParser.parse(%{"data" => %{}})
      assert [] = ControlParser.parse(%{"data" => %{"controls" => nil}})
    end

    test "returns empty list for empty controls array" do
      assert [] = ControlParser.parse(%{"data" => %{"controls" => []}})
    end

    test "parses file_done control into upload_attachment event" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "file_done",
                "fileId" => 123,
                "data" => %{"url" => "https://example.com/file.jpg"}
              }
            }
          ]
        }
      }

      assert [{:upload_attachment, %{file_id: "123", file_url: "https://example.com/file.jpg"}}] =
               ControlParser.parse(payload)
    end

    test "parses file_done with string file_id" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "file_done",
                "fileId" => "abc-456",
                "data" => %{"url" => "https://example.com/doc.pdf"}
              }
            }
          ]
        }
      }

      assert [{:upload_attachment, %{file_id: "abc-456", file_url: "https://example.com/doc.pdf"}}] =
               ControlParser.parse(payload)
    end

    test "parses group control into group_event" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "group",
                "act" => "join",
                "data" => %{"groupId" => "g123", "memberId" => "u456"}
              }
            }
          ]
        }
      }

      assert [{:group_event, %{act: "join", data: %{"groupId" => "g123", "memberId" => "u456"}}}] =
               ControlParser.parse(payload)
    end

    test "parses group control with JSON string data" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "group",
                "act" => "leave",
                "data" => ~s({"groupId":"g123","memberId":"u456"})
              }
            }
          ]
        }
      }

      assert [{:group_event, %{act: "leave", data: %{"groupId" => "g123", "memberId" => "u456"}}}] =
               ControlParser.parse(payload)
    end

    test "ignores group join_reject events" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "group",
                "act" => "join_reject",
                "data" => %{"groupId" => "g123"}
              }
            }
          ]
        }
      }

      assert [] = ControlParser.parse(payload)
    end

    test "parses friend control into friend_event" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "fr",
                "act" => "accept",
                "data" => %{"userId" => "u789", "name" => "John"}
              }
            }
          ]
        }
      }

      assert [{:friend_event, %{act: "accept", data: %{"userId" => "u789", "name" => "John"}}}] =
               ControlParser.parse(payload)
    end

    test "parses friend control with JSON string data" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "fr",
                "act" => "req_v2",
                "data" => ~s({"userId":"u789","message":"Hello"})
              }
            }
          ]
        }
      }

      assert [{:friend_event, %{act: "req_v2", data: %{"userId" => "u789", "message" => "Hello"}}}] =
               ControlParser.parse(payload)
    end

    test "ignores friend req events (only handles req_v2)" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "fr",
                "act" => "req",
                "data" => %{"userId" => "u789"}
              }
            }
          ]
        }
      }

      assert [] = ControlParser.parse(payload)
    end

    test "parses friend event with topic.params string into parsed JSON" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "fr",
                "act" => "pin_create",
                "data" => %{
                  "topic" => %{
                    "id" => "t123",
                    "params" => ~s({"key":"value","num":42})
                  }
                }
              }
            }
          ]
        }
      }

      assert [{:friend_event, %{act: "pin_create", data: parsed_data}}] =
               ControlParser.parse(payload)

      assert %{"topic" => %{"id" => "t123", "params" => %{"key" => "value", "num" => 42}}} =
               parsed_data
    end

    test "parses multiple controls in a single payload" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "file_done",
                "fileId" => "f1",
                "data" => %{"url" => "https://example.com/1.jpg"}
              }
            },
            %{
              "content" => %{
                "act_type" => "group",
                "act" => "join",
                "data" => %{"groupId" => "g1"}
              }
            },
            %{
              "content" => %{
                "act_type" => "fr",
                "act" => "accept",
                "data" => %{"userId" => "u1"}
              }
            }
          ]
        }
      }

      events = ControlParser.parse(payload)
      assert length(events) == 3

      assert {:upload_attachment, %{file_id: "f1", file_url: "https://example.com/1.jpg"}} =
               Enum.at(events, 0)

      assert {:group_event, %{act: "join", data: %{"groupId" => "g1"}}} = Enum.at(events, 1)
      assert {:friend_event, %{act: "accept", data: %{"userId" => "u1"}}} = Enum.at(events, 2)
    end

    test "skips controls with unknown act_type" do
      payload = %{
        "data" => %{
          "controls" => [
            %{
              "content" => %{
                "act_type" => "unknown_type",
                "act" => "something",
                "data" => %{}
              }
            }
          ]
        }
      }

      assert [] = ControlParser.parse(payload)
    end

    test "skips controls with missing content" do
      payload = %{
        "data" => %{
          "controls" => [
            %{"something" => "else"},
            %{}
          ]
        }
      }

      assert [] = ControlParser.parse(payload)
    end

    test "skips file_done controls with missing required fields" do
      payload = %{
        "data" => %{
          "controls" => [
            %{"content" => %{"act_type" => "file_done"}},
            %{"content" => %{"act_type" => "file_done", "fileId" => "123"}},
            %{"content" => %{"act_type" => "file_done", "data" => %{"url" => "https://x.com"}}}
          ]
        }
      }

      assert [] = ControlParser.parse(payload)
    end
  end
end
