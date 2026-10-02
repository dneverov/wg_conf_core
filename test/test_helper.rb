# frozen_string_literal: true

# Добавляем папку lib в пути загрузки Ruby
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Подключаем главный файл нашего гема
require "wg_conf_core"

# Подключаем Minitest
require "minitest/autorun"
