# frozen_string_literal: true

class VpnConfigParser
  class << self
    # Извлекает IP-адрес из строки вида Endpoint = 192.168.1.1:51820
    def extract_endpoint_ip(config_name)
      target_dir = Config.target_dir
      # Формируем полный путь к файлу конфигурации
      file_path = File.join(target_dir, "#{config_name}.conf")

      unless File.exist?(file_path)
        raise "Файл конфигурации не найден для парсинга: #{file_path}"
      end

      File.foreach(file_path) do |line|
        # Ищем строку Endpoint, игнорируя регистр и пробелы
        if line =~ /^\s*Endpoint\s*=\s*([^:]+)/i
          return $1.strip
        end
      end

      raise "В файле #{config_name}.conf не найдена директива Endpoint с IP-адресом."
    end
  end
end
