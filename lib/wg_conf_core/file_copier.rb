require 'fileutils'
require 'date'
require_relative 'config'
require_relative 'copier'

class FileCopier
  class << self
    def sync!(period_arg: "0")
      # Валидация директорий и входных данных
      source, _ = validate_directories!
      period = parse_and_validate_period!(period_arg)

      # Поиск конфигурационных файлов
      files = find_config_files(source)

      # Фильтрация по дате
      recent_files = filter_files(files, period: period)

      # Копирование
      copy_files!(recent_files)
    end

    private

      def copy_files!(files_to_copy)
        copier = Copier.new
        target_dir = Config.target_dir

        files_to_copy.map do |file_path|
          file_name = File.basename(file_path)
          begin
            target_name = copier.rename_and_copy(file_name)
            # Сразу генерируем полный финальный путь назначения
            full_target_path = copier.set_path(target_dir, target_name)

            { file: file_name, success: true, target_path: full_target_path }
          rescue StandardError => e
            { file: file_name, success: false, error: e.message }
          end
        end
      end

      # Ищет поддерживаемые типы файлов в папке-источнике
      def find_config_files(source)
        files = Config.find_files(source, '*.{conf,wg,json,vpn}')

        if files.empty?
          raise RuntimeError, "В папке #{source} не найдено файлов конфигураций для копирования."
        end

        files
      end

      # Фильтрует массив файлов по дате
      def filter_files(files, period: 0)
        # Если :all, сразу возвращаем файлы и выходим из метода
        return files.select { |f| File.file?(f) } if period == :all

        date_range = (Date.today - period)..Date.today

        files.select do |file|
          File.file?(file) && date_range.cover?(File.mtime(file).to_date)
        end
      end

      # Проверяет существование папок и возвращает их пути кортежем
      def validate_directories!
        source = Config.source_dir
        target = Config.target_dir

        raise "Исходная папка не существует (#{source})" unless Dir.exist?(source)
        raise "Целевая папка не найдена (#{target})"     unless Dir.exist?(target)

        [source, target]
      end

      # Проверяет строку из консоли и преобразует в правильный тип данных
      def parse_and_validate_period!(period_arg)
        unless period_arg == "all" || period_arg =~ /\A\d+\z/
          raise ArgumentError, "Неверный формат периода '#{period_arg}'. Используйте число дней (например: -p 3), 0 или 'all'."
        end

        period_arg == "all" ? :all : period_arg.to_i
      end
  end
end
