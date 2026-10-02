class Namer
  COUNTRY_MAPPING = {
    "unitedkingdom" => "UK",
    "czechrepublic" => "cze",
    "usa"           => "USA"
  }

  # Rename pattern
  RENAME_PATTERN = 'wg2_%.3s_%.3s_%s.conf'

  def self.new_config_name(source_file)
    # Get [country_code, city_code, suffix]
    parts = Namer.extract_parts(source_file)

    # Склеиваем по шаблону с помощью оператора %
    new_name = RENAME_PATTERN % parts

    new_name.gsub('_.conf', '.conf')
  end

  # Returns [country_code, city_code, suffix]
  def self.extract_parts(source_file)
    # 1. Отрезаем расширение (работает с .conf, .txt и любыми другими)
    clean_name = File.basename(source_file, ".*")

    # 2. Разделяем CamelCase пробелами
    formatted = clean_name
                  .gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2')
                  .gsub(/([a-z\d])([A-Z])/, '\1 \2')
    parts = formatted.split

    return [clean_name.downcase, "", ""] if parts.size < 2

    # 3. Проверяем последнее слово. Если это суффикс вида S2, S3, S4:
    if parts.last.match?(/^[A-Za-z]\d+$/)
      suffix = parts.last
      name_parts = parts[0...-1] # Страна и город — всё, кроме суффикса
    else
      suffix = "" # Суффикса нет (как в ChileSantiago)
      name_parts = parts # Страна и город — это весь массив
    end

    country_code = nil
    city_words = []

    # 4. Проверяем составную страну из двух слов
    first_two_joined = (name_parts[0..1] || []).join.downcase

    if name_parts.size >= 2 && COUNTRY_MAPPING.key?(first_two_joined)
      country_code = COUNTRY_MAPPING[first_two_joined]
      city_words = name_parts[2..-1] || []
    else
      # 5. Проверяем простую страну из одного слова
      first_word = name_parts.first.downcase
      country_code = COUNTRY_MAPPING[first_word] || first_word
      city_words = name_parts[1..-1] || []
    end

    # Склеиваем слова города в нижний регистр
    city_code = city_words.join.downcase

    # Возвращаем чистые компоненты
    [country_code, city_code, suffix]
  end
end
