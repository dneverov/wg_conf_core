require 'yaml'
require 'fileutils'

class Config
  AVAILABLE_SERVICES = {
    amnezia:   'awg-quick@', # AmneziaWG
    wireguard: 'wg-quick@'   # WireGuard
  }.freeze # Замораживаем хэш, чтобы защитить от случайного изменения

  # По умолчанию используем amnezia, но в будущем сюда можно добавить чтение из @data.dig(...)
  VPN_SERVICE = AVAILABLE_SERVICES[:amnezia]

  class << self
    def source_dir
      expand_path fetch_config('source_dir', default: '')
    end

    def target_dir
      expand_path fetch_config('target_dir', default: '')
    end

    def ping_host
      fetch_config('ping_host', default: '1.1.1.1')
    end

    # Публичный хелпер для получения префикса сервиса
    def vpn_service
      VPN_SERVICE
    end

    # Универсальный хелпер для поиска файлов по маске
    def find_files(directory, extension_mask)
      Dir.glob(File.join(directory, extension_mask))
    end

    # Рендерит разделитель интерфейса в указанный поток (по умолчанию $stdout)
    def render_divider(stream = $stdout, length: 50, char: "-")
      stream.puts char * length
    end

    # Выносим инициализацию в метод класса, чтобы его можно было безопасно перезапускать
    def load_data!
      file_path = ENV['CONFIG_PATH'] || 'config.yml'
      example_path = "#{file_path}.example"

      if !File.exist?(file_path) && File.exist?(example_path)
        puts "Локальный #{file_path} не найден. Создаю из шаблона..."
        FileUtils.cp(example_path, file_path)
      end

      raise "Файл конфигурации не найден: #{file_path}" unless File.exist?(file_path)

      @data = YAML.load_file(file_path)
      @loaded = true # Взводим флаг успешной загрузки
    end

    # Мягкое предупреждение или перезапуск
    def check_root_privileges(strict: false)
      # Если запущены тесты, пропускаем проверку прав, чтобы не вызывать exec('sudo')
      return if ENV['TEST_ENV'] == 'true'
      return if Process.euid == 0 # Используем euid для точной проверки эффективных прав root

      if strict
        puts "Для работы скрипта требуются права суперпользователя. Перезапуск через sudo..."
        render_divider

        # 1. Выясняем точный путь к текущему работающему Ruby (например, RVM-версии)
        current_ruby = Gem.ruby

        # 2. Формируем базовую команду повышения прав
        # Флаг -E критически важен, чтобы sudo не сбрасывал переменные окружения (пути RVM, CONFIG_PATH и т.д.)
        cmd = ["sudo", "-E", current_ruby]

        # 3. Если скрипт был запущен в контексте bundle exec, 
        # прокидываем автозагрузку зависимостей бандла в новый root-процесс
        if defined?(Bundler) && ENV['BUNDLE_GEMFILE']
          cmd += ["-rbundler/setup"]
        end

        # 4. Добавляем сам файл скрипта ($0) и все переданные аргументы командной строки
        cmd << $0
        cmd += ARGV

        # exec заменяет текущий процесс новым с правами root
        exec(*cmd)
      else
        script_name  = File.basename($0)
        current_args = ARGV.join(' ')

        puts "Примечание: Скрипт запущен без прав суперпользователя."
        puts "Если целевая папка защищена от записи, может потребоваться:"
        puts "  sudo ruby #{script_name} #{current_args}".rstrip
        render_divider
      end
    rescue SystemCallError
      # Твой оригинальный перехватчик на месте! Если sudo сломается, скрипт выйдет красиво
      puts "Ошибка: Не удалось получить права суперпользователя."
      exit 1
    end

    # Универсальный хелпер для безопасного глушения консольного спама
    def silence_output
      original_stdout = $stdout
      # Перенаправляем $stdout в пустоту
      $stdout = File.open(File::NULL, 'w')
      yield original_stdout
    ensure
      $stdout.close rescue nil
      $stdout = original_stdout
    end

    private

      # Универсальный хелпер для извлечения настроек
      def fetch_config(key, default:)
        # Если данные еще не загружались — лениво загружаем их прямо сейчас
        load_data! unless defined?(@loaded) && @loaded

        @data.dig('config', key) || default
      end

      # File.expand_path автоматически превратит '~/' в '/home/user/'
      def expand_path(path)
        File.expand_path(path)
      end
  end
end
