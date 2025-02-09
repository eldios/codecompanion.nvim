---@diagnostic disable: unused-local
local config = require("codecompanion.config")
local curl = require("plenary.curl")
local log = require("codecompanion.utils.log")
local utils = require("codecompanion.utils.adapters")

return {
  name = "OpenWebUI",
  options = {
    model = {
      default = "mistralai/Mistral-7B-Instruct-v0.2",
      prompt = "The model to use for the request",
    },
    temperature = {
      default = 0.7,
      prompt = "The temperature to use for sampling",
    },
    top_p = {
      default = 0.9,
      prompt = "The top_p value to use for sampling",
    },
    top_k = {
      default = 50,
      prompt = "The top_k value to use for sampling",
    },
    max_tokens = {
      default = 256,
      prompt = "The maximum number of tokens to generate",
      tokens = true,
      vision = false,
    },
  },
  url = "${url}/{chat_url}",
  env = {
    url = "http://localhost:8080",
    chat_url = "api/chat",
    api_key = "",
  },
  handlers = {
    ---Set the parameters
    ---@param self CodeCompanion.Adapter
    ---@param params table
    ---@param messages table
    ---@return table
    form_parameters = function(self, params, messages)
      return params
    end,

    ---Set the format of the role and content for the messages from the chat buffer
    ---@param self CodeCompanion.Adapter
    ---@param messages table Format is: { { role = "user", content = "Your prompt here" } }
    ---@return table
    form_messages = function(self, messages)
      local formatted_messages = {}
      for _, message in ipairs(messages) do
        table.insert(formatted_messages, {
          role = message.role,
          content = message.content,
        })
      end
      return { inputs = formatted_messages }
    end,

    ---Parses the output for a chat buffer
    ---@param self CodeCompanion.Adapter
    ---@param data string
    ---@return string
    chat_output = function(self, data)
      local response = vim.json.decode(data)
      if response and response.response then
        return response.response
      else
        return "Error: Could not parse response"
      end
    end,

    ---Parses the output for inline buffer
    ---@param self CodeCompanion.Adapter
    ---@param data string
    ---@param context table
    ---@return string
    inline_output = function(self, data, context)
      local response = vim.json.decode(data)
      if response and response.response then
        return response.response
      else
        return "Error: Could not parse response"
      end
    end,

    ---Parses the tokens from the response
    ---@param self CodeCompanion.Adapter
    ---@param data string
    ---@return integer
    tokens = function(self, data)
      local response = vim.json.decode(data)
      return response.tokens
    end,

    ---@param self CodeCompanion.Adapter
    ---@param data string
    on_exit = function(self, data)
      -- Messaage on exit
    end,
  },
  ---@param response table
  ---@return string|nil
  check_error = function(response)
    if response.status_code ~= 200 then
      local ok, json = pcall(vim.json.decode, response.body)
      if not ok then
        return "Failed to decode JSON: " .. response.body
      end

      if json and json.error then
        return "Error: " .. json.error
      else
        return "Request failed with status code: " .. response.status_code .. " and body: " .. response.body
      end
    end
    return nil
  end,

  ---@param opts table
  ---@return table
  get_headers = function(opts)
    local headers = {}
    if opts.env.api_key and opts.env.api_key ~= "" then
      headers["Authorization"] = "Bearer " .. opts.env.api_key
    end
    return headers
  end,
}
