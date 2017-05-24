defmodule Gittp.Web.Plugs.ValidateApiKeyPlug do
   import Plug.Conn
   require Logger

   def init(_) do
       System.get_env("API_KEYS_FILE_PATH")
       |> File.stream!([:read, :utf8])
       |> Enum.reduce([], fn (current, list) -> [current | list] end)
   end

   def call(conn, authorized_keys) do
       api_key = get_req_header(conn, "gittp-api-key")  
       validate_key(conn, api_key, authorized_keys)
   end

   def validate_key(conn, [], _) do
       send_unauthorized conn
   end 

   def validate_key(conn, [api_key], authorized_keys) do
       case Enum.any?(authorized_keys, fn key -> String.equivalent?(key, api_key) end) do
           false -> send_unauthorized(conn)
           true -> conn
       end
   end

   defp send_unauthorized(conn) do
       conn |> Plug.Conn.send_resp(401, "invalid api key") |> Plug.Conn.halt
   end
end