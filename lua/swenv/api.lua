local M = {}

local settings = require('swenv.config').settings

local ORIGINAL_PATH = vim.fn.getenv('PATH')

local current_venv = nil

local update_path = function(path)
  vim.fn.setenv('PATH', path .. '/bin' .. ':' .. ORIGINAL_PATH)
end

local set_venv = function(venv)
  if venv.source == 'conda' then
    vim.fn.setenv('CONDA_PREFIX', venv.path)
    vim.fn.setenv('CONDA_DEFAULT_ENV', venv.name)
    vim.fn.setenv('CONDA_PROMPT_MODIFIER', '(' .. venv.name .. ')')
  else
    vim.fn.setenv('VIRTUAL_ENV', venv.path)
  end

  current_venv = venv
  -- TODO: remove old path
  update_path(venv.path)

  if settings.post_set_venv then
    settings.post_set_venv(venv)
  end
end

M.get_current_venv = function()
  return current_venv
end

M.get_venvs = function(venvs_path)
  local success, Path = pcall(require, 'plenary.path')
  if not success then
    vim.notify('Could not require plenary: ' .. Path, vim.log.levels.WARN)
    return
  end
  local scan_dir = require('plenary.scandir').scan_dir

  local venvs = {}

  -- CONDA
  local conda_exe = vim.fn.getenv('CONDA_EXE')
  if conda_exe ~= vim.NIL then
    local conda_env_path = Path:new(conda_exe):parent():parent() .. '/envs'
    local conda_paths = scan_dir(conda_env_path, { depth = 1, only_dirs = true, silent = true })

    for _, path in ipairs(conda_paths) do
      table.insert(venvs, {
        name = Path:new(path):make_relative(conda_env_path),
        path = path,
        source = 'conda',
      })
    end
  end

  local pipfile_exe = vim.fn.executable('pipenv')
  local pipfile_path = vim.fn.getcwd() .. '/Pipfile'

  if pipfile_exe ~= vim.NIL and Path:new(pipfile_path):exists() then
    local pipfile_env_path = vim.env.HOME .. '/.local/share/virtualenvs'
    local pipfile_paths = scan_dir(pipfile_env_path, { depth = 1, only_dirs = true, silent = true })
    for _, path in ipairs(pipfile_paths) do
      table.insert(venvs, {
        name = Path:new(path):make_relative(pipfile_env_path),
        path = path,
        source = 'pipenv',
      })
    end
  end

  -- VENV
  local paths = scan_dir(venvs_path, { depth = 1, only_dirs = true, silent = true })
  for _, path in ipairs(paths) do
    table.insert(venvs, {
      -- TODO how does one get the name of the file directly?
      name = Path:new(path):make_relative(venvs_path),
      path = path,
      source = 'venv',
    })
  end

  return venvs
end

M.pick_venv = function()
  vim.ui.select(settings.get_venvs(settings.venvs_path), {
    prompt = 'Select python venv',
    format_item = function(item)
      return string.format('%s (%s) [%s]', item.name, item.path, item.source)
    end,
  }, function(choice)
    if not choice then
      return
    end
    set_venv(choice)
  end)
end

return M
