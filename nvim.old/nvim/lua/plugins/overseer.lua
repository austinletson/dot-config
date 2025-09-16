return {
  "stevearc/overseer.nvim",
  opts = {
    -- You can put your default overseer options here if needed
    -- For example:
    -- task_list = {
    --   direction = "bottom",
    --   min_height = 25,
    --   max_height = 25,
    --   default_detail = 1,
    -- },
  },
  config = function(_, opts)
    require("overseer").setup(opts)

    -- Helper function to find the dbt project root by looking for dbt_project.yml
    local function find_dbt_project_root(start_file_path)
      if not start_file_path or start_file_path == "" then
        return nil
      end

      local current_dir = vim.fn.fnamemodify(start_file_path, ":p:h")

      if not current_dir or current_dir == "" or not vim.loop.fs_stat(current_dir) then
        return nil
      end

      local project_files = vim.fs.find({"dbt_project.yml"}, {
        upward = true,
        path = current_dir,
        type = "file",
        limit = 1,
      })

      if project_files and #project_files > 0 then
        return vim.fn.fnamemodify(project_files[1], ":p:h")
      end
      return nil
    end

    require("overseer").register_template({
      name = "DBT Build Current Model",
      builder = function()
        local current_bufnr = vim.api.nvim_get_current_buf()
        local current_file_path = vim.api.nvim_buf_get_name(current_bufnr)

        if not current_file_path or current_file_path == "" then
          vim.notify("Overseer: Current buffer is not associated with a file.", vim.log.levels.WARN)
          return
        end

        local model_name = vim.fn.fnamemodify(current_file_path, ":t:r")
        local file_ext = vim.fn.fnamemodify(current_file_path, ":e")

        if file_ext ~= "sql" then
          vim.notify("Overseer: Current file is not a .sql file (" .. current_file_path .. ").", vim.log.levels.WARN)
          return
        end

        if not model_name or model_name == "" then
          vim.notify("Overseer: Could not determine model name from file: " .. current_file_path, vim.log.levels.WARN)
          return
        end

        local project_root = find_dbt_project_root(current_file_path)
        if not project_root then
          vim.notify("Overseer: dbt_project.yml not found for: " .. current_file_path .. ". Make sure you are in a dbt project.", vim.log.levels.ERROR)
          return
        end

        return {
          cmd = {"dbt", "build", "-s", model_name},
          cwd = project_root,
          name = "dbt build -s " .. model_name,
          strategy = "terminal",
        }
      end,
      condition = {
        callback = function(bufnr)
          local bufnr_to_check = (type(bufnr) == "number") and bufnr or vim.api.nvim_get_current_buf()
          local file_path = vim.api.nvim_buf_get_name(bufnr_to_check)

          if not file_path or file_path == "" then return false end
          if vim.fn.fnamemodify(file_path, ":e") ~= "sql" then return false end
          return find_dbt_project_root(file_path) ~= nil
        end,
      },
    })

    require("overseer").register_template({
      name = "DBT Compile File",
      builder = function()
        local current_bufnr = vim.api.nvim_get_current_buf()
        local current_file_path = vim.api.nvim_buf_get_name(current_bufnr)

        if not current_file_path or current_file_path == "" then
          vim.notify("Overseer: Current buffer is not associated with a file.", vim.log.levels.WARN)
          return
        end

        local project_root = find_dbt_project_root(current_file_path)
        if not project_root then
          vim.notify("Overseer: dbt_project.yml not found for: " .. current_file_path .. ". Make sure you are in a dbt project.", vim.log.levels.ERROR)
          return
        end

        local file_name = vim.fn.fnamemodify(current_file_path, ":t:r")

        return {
          cmd = { "dbt", "compile", "-s", file_name },
          cwd = project_root,
          name = "dbt compile -s " .. file_name,
          strategy = "terminal",
        }
      end,
      condition = {
        callback = function(bufnr)
          local bufnr_to_check = (type(bufnr) == "number") and bufnr or vim.api.nvim_get_current_buf()
          local file_path = vim.api.nvim_buf_get_name(bufnr_to_check)

          if not file_path or file_path == "" then return false end
          return find_dbt_project_root(file_path) ~= nil
        end,
      },
    })

    -- You can add more dbt-related task templates here
    vim.notify("DBT Overseer tasks registered", vim.log.levels.INFO) -- Optional: for confirmation
  end,
  -- Optional: Add lazy-loading conditions if desired
  -- event = "VeryLazy",
  -- cmd = "OverseerRun",
}
