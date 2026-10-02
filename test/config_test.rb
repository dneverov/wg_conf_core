require_relative 'unit_test_case'

class ConfigTest < UnitTestCase
  # Автоматически генерирует константы TEST_DIR и CONFIG_FILE (как test_files_config)
  setup_unit_paths 'config'

  # Создаем константу для .example файла на основе сгенерированной базовым классом
  EXAMPLE_FILE = "#{CONFIG_FILE}.example"

  # Автоматически глушим любой puts/print во время выполнения тестов этого класса
  def run(*args, &block)
    Config.silence_output { super }
  end

  def setup
    # Всегда явно прописываем ENV перед тестом
    ENV['CONFIG_PATH'] = CONFIG_FILE
    FileUtils.mkdir_p(TEST_DIR)
    clean_files
  end

  def teardown
    clean_files
    super # Вызывает базовый teardown, который удалит папки и очистит ENV['CONFIG_PATH']
  end

  # --- ТЕСТЫ ---

  def test_correctly_parses_paths_and_expands_tilde
    config_hash = {
      'source_dir' => '~/Downloads/amnezia_wg2.0',
      'target_dir' => '~/Downloads/1'
    }

    write_yaml_config(CONFIG_FILE, config_hash)

    # Принудительно заставляем конфиг перечитать файлы с диска
    Config.load_data!

    expected_source = File.expand_path(config_hash['source_dir'])
    expected_target = File.expand_path(config_hash['target_dir'])

    assert_equal expected_source, Config.source_dir
    assert_equal expected_target, Config.target_dir
  end

  def test_creates_config_from_example_if_missing
    # Создаем ТОЛЬКО .example файл
    config_hash = {
      'source_dir' => '~/FromExample',
      'target_dir' => '~/ToExample'
    }

    write_yaml_config(EXAMPLE_FILE, config_hash)

    Config.load_data!

    assert File.exist?(CONFIG_FILE), "Тестовый конфиг должен был создаться автоматически"
    assert_equal File.expand_path(config_hash['source_dir']), Config.source_dir
    assert_equal File.expand_path(config_hash['target_dir']), Config.target_dir
  end

  def test_raises_error_if_no_files_exist
    clean_files

    # Теперь метод гарантированно выбросит RuntimeError, так как файлов нет
    assert_raises(RuntimeError) do
      Config.load_data!
    end
  end

  private

    def clean_files
      FileUtils.rm_f(CONFIG_FILE)
      FileUtils.rm_f(EXAMPLE_FILE)
    end

    def write_yaml_config(file, hash)
      File.write(file, { 'config' => hash }.to_yaml)
    end
end
