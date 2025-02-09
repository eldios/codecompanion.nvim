local curl = require("plenary.curl")
local log = require("codecompanion.utils.log")

local function get_env_vars(self)
  -- Initialize env_replaced if it doesn't exist
  self.env_replaced = self.env_replaced or {}
  -- Copy environment variables
  self.env_replaced.url = self.env.url
  self.env_replaced.chat_url = self.env.chat_url
  self.env_replaced.api_key = self.env.api_key
end

local function get_models(self, opts)
  self:get_env_vars()
  local url = self.env_replaced.url .. "/api/models"
  local headers = self:get_headers({ env = self.env_replaced })

  local response = curl.get(url, {
    headers = headers,
  })

  local status, result = pcall(vim.json.decode, response.body)
  if not status or response.status ~= 200 then
    log:error("Failed to fetch models: " .. (result and result.error or "Unknown error"))
    return {}
  end

  return result.models or {}
end

return {
  name = "OpenWebUI",
  options = {
    model = {
      default = "llama2",
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
      default = 2048,
      prompt = "The maximum number of tokens to generate",
      tokens = true,
      vision = false,
    },
  },
  url = "${url}/${chat_url}",
  env = {
    url = "http://localhost:8080",
    chat_url = "api/chat",
    api_key = "",
  },
  handlers = {
    get_env_vars = get_env_vars,

    form_parameters = function(_, params, _)
      return {
        model = params.model,
        temperature = params.temperature,
        top_p = params.top_p,
        top_k = params.top_k,
        max_tokens = params.max_tokens,
      }
    end,

    form_messages = function(_, messages)
      local formatted_messages = {}
      for _, message in ipairs(messages) do
        table.insert(formatted_messages, {
          role = message.role,
          content = message.content,
        })
      end
      return {
        messages = formatted_messages,
      }
    end,

    chat_output = function(_, data)
      local ok, response = pcall(vim.json.decode, data)
      if ok and response and response.choices and response.choices[1] and response.choices[1].message then
        return response.choices[1].message.content
      else
        return "Error: Could not parse response"
      end
    end,

    inline_output = function(_, data, _)
      local ok, response = pcall(vim.json.decode, data)
      if ok and response and response.choices and response.choices[1] and response.choices[1].message then
        return response.choices[1].message.content
      else
        return "Error: Could not parse response"
      end
    end,

    tokens = function(_, data)
      local ok, response = pcall(vim.json.decode, data)
      if ok and response and response.usage then
        return response.usage.total_tokens
      end
      return 0
    end,

    check_error = function(response)
      if response.status ~= 200 then
        local ok, json = pcall(vim.json.decode, response.body)
        if not ok then
          return "Failed to decode JSON: " .. response.body
        end

        if json and json.error then
          return "Error: " .. json.error
        else
          return "Request failed with status code: " .. response.status .. " and body: " .. response.body
        end
      end
      return nil
    end,

    get_headers = function(opts)
      local headers = {
        ["Content-Type"] = "application/json",
      }
      if opts.env.api_key and opts.env.api_key ~= "" then
        headers["Authorization"] = "Bearer " .. opts.env.api_key
      end
      return headers
    end,
  },
  get_models = get_models,
}
