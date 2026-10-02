# frozen_string_literal: true

# Добавляем подключение хелпера гема, чтобы гарантировать загрузку Config, VpnRunner и т.д.
require_relative 'test_helper'

require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'stringio'

class UnitTestCase < Minitest::Test
  # Хелпер для динамического задания путей
  def self.setup_unit_paths(dir_suffix)
    const_set(:TEST_DIR,     File.expand_path("../test_files_#{dir_suffix}", __dir__))
    const_set(:CONFIG_FILE,  File.join(self::TEST_DIR, 'config_test.yml'))
    const_set(:SRC_MOCK_DIR, File.join(self::TEST_DIR, 'src_mock'))
    const_set(:TXT_MOCK_DIR, File.join(self::TEST_DIR, 'target_mock'))
  end

  def setup
    # 1. Если у дочернего класса объявлены пути, создаем папки на диске
    if defined?(self.class::TEST_DIR)
      FileUtils.mkdir_p(self.class::TEST_DIR)
      FileUtils.mkdir_p(self.class::SRC_MOCK_DIR)
      FileUtils.mkdir_p(self.class::TXT_MOCK_DIR)

      # 2. Инициализируем YAML-конфиг (нужно для FileCopierTest и CopierTest)
      ENV['CONFIG_PATH'] = self.class::CONFIG_FILE
      # Записываем конфигурацию и принудительно перечитываем её в память
      write_test_config(self.class::SRC_MOCK_DIR, self.class::TXT_MOCK_DIR)
      Config.load_data!
    end
  end

  def teardown
    FileUtils.rm_rf(self.class::TEST_DIR) if defined?(self.class::TEST_DIR)
    ENV.delete('CONFIG_PATH')
  end

  private

    # Переиспользуемый хелпер для создания файлов конфигурации
    def create_mock_config(directory, name, days_old: 0, content: 'dummy')
      file_path = File.join(directory, name)
      File.write(file_path, content)

      if days_old > 0
        target_time = Time.now - (days_old * 24 * 60 * 60)
        File.utime(target_time, target_time, file_path) # Используем File.utime вместо FileUtils.touch
      end

      file_path
    end

    def write_test_config(source, target)
      hash = { 'config' => { 'source_dir' => source, 'target_dir' => target } }
      File.write(self.class::CONFIG_FILE, hash.to_yaml)
    end

    # --- Универсальные хелперы метапрограммирования ---
    def replace_method(klass, original_name, backup_name, &block)
      klass.singleton_class.class_eval do
        # Проверяем и публичные, и приватные методы для бэкапа
        is_private = private_method_defined?(original_name)
        alias_method backup_name, original_name if method_defined?(original_name) || is_private
        define_method(original_name, &block)
        # Если оригинальный метод был приватным, сохраняем эту приватность и для заглушки
        private original_name if is_private
      end
    end

    def restore_method(klass, original_name, backup_name)
      klass.singleton_class.class_eval do
        is_private = private_method_defined?(backup_name)
        if method_defined?(backup_name) || is_private
          remove_method original_name
          alias_method original_name, backup_name
          # Явно возвращаем методу статус private, если он был таким изначально
          private original_name if is_private
          remove_method backup_name
        end
      end
    end
end
