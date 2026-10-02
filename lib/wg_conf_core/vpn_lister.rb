require_relative 'config'

class VpnLister
  class << self
    # Основной метод, который возвращает готовую строку для вывода в терминал
    def render(sort_by: :name, columns: 3, verbose_time: false)
      files = fetch_and_normalize_files

      if files.empty?
        raise RuntimeError, "В папке конфигураций нет доступных VPN-интерфейсов."
      end

      sorted_files = sort_files(files, sort_by)

      # Вычисляем длину
      max_name_len = sorted_files.map { |f| f[:name].length }.max || 0

      # Получаем массив форматированных ячеек
      items = prepare_items(sorted_files, max_name_len, verbose_time)

      # Получаем всю геометрию сетки одной строкой через деструктуризацию массива
      actual_cols, col_width = determine_layout(max_name_len, columns, verbose_time)

      # Передаем уже готовую col_width в метод сетки
      format_vertical_columns(items, actual_cols, col_width)
    end

    private

      # 1. Шаг: Собираем файлы и сразу нормализуем их в понятную структуру хэшей
      def fetch_and_normalize_files
        target_dir = Config.target_dir

        unless File.directory?(target_dir) && File.readable?(target_dir)
          raise Errno::EACCES, "Недостаточно прав для чтения директории #{target_dir}."
        end

        all_files = Config.find_files(target_dir, '*.conf')

        all_files.map do |f|
          full_path = f.start_with?('/') ? f : File.join(target_dir, f)
          {
            name:  File.basename(f, '.conf'),
            mtime: File.mtime(full_path)
          }
        end
      end

      # 2. Шаг: Чистая сортировка массива хэшей в памяти
      def sort_files(files, sort_by)
        case sort_by
        when :time
          # Сортировка по времени изменения (свежие выше)
          files.sort_by { |item| item[:mtime] }.reverse
        else
          # Сортировка по имени по умолчанию
          files.sort_by { |item| item[:name].downcase }
        end
      end

      # Вычисляем параметры отображения на основе флага
      def determine_layout(max_name_len, default_columns, verbose_time)
        if verbose_time
          # Ширина: имя + 1 пробел + 16 символов даты + 3 пробела отступа = max + 20
          [2, max_name_len + 20]
        else
          # Ширина: имя + 3 пробела отступа
          [default_columns, max_name_len + 3]
        end
      end

      # 3. Шаг: Форматирование ячеек на основе переданной длины
      def prepare_items(files, max_name_len, verbose_time)
        # Определяем правило трансформации
        formatter =
          if verbose_time
            -> (item) { "#{item[:name].ljust(max_name_len)} #{item[:mtime].strftime('%Y-%m-%d %H:%M')}" }
          else
            -> (item) { item[:name] }
          end

        # Отдаём готовое правило в map.
        files.map(&formatter)
      end

      # 4. Шаг: Математика вертикального распределения колонок
      def format_vertical_columns(items, col_count, col_width)
        # Рассчитываем, сколько строк нам понадобится (округление вверх)
        row_count = (items.size.to_f / col_count).ceil

        lines = []
        # Итерируемся по строкам
        row_count.times do |row_idx|
          row_items = []

          # Для каждой строки собираем элементы, которые должны стоять в разных колонках
          col_count.times do |col_idx|
            # Индекс элемента в плоском массиве при вертикальном заполнении
            item_idx = col_idx * row_count + row_idx

            if item_idx < items.size
              row_items << items[item_idx].ljust(col_width)
            end
          end

          lines << row_items.join.strip
        end

        lines.join("\n")
      end
  end
end
