# frozen_string_literal: true

require_relative "wg_conf_core/version"

# Подключаем все файлы бизнес-логики
require_relative "wg_conf_core/config"
require_relative "wg_conf_core/system_executor"
require_relative "wg_conf_core/copier"
require_relative "wg_conf_core/file_copier"
require_relative "wg_conf_core/namer"
require_relative "wg_conf_core/vpn_lister"
require_relative "wg_conf_core/vpn_pinger"
require_relative "wg_conf_core/vpn_runner"
require_relative "wg_conf_core/vpn_config_parser"
require_relative "wg_conf_core/vpn_shield"

module WgConfCore
  class Error < StandardError; end
  # Your code goes here...
end
