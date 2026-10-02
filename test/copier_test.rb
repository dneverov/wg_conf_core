require_relative 'unit_test_case'

class CopierTest < UnitTestCase
  # Генерируем константы путей, если они понадобятся, и настраиваем YAML-конфиг
  setup_unit_paths 'copier'

  def setup
    super # Вызывает базовый setup для подготовки папок и YAML

    # Подставляем заглушки, используя унаследованные из базы хелперы replace_method
    replace_method(Config, :source_dir, :orig_source) { '/mock/source' }
    replace_method(Config, :target_dir, :orig_target) { '/mock/target' }
    replace_method(Namer, :new_config_name, :orig_name) { |source| "mocked_#{source}" }

    @copier = Copier.new
  end

  def teardown
    # Восстанавливаем оригинальные методы из файлов lib/
    restore_method(Config, :source_dir, :orig_source)
    restore_method(Config, :target_dir, :orig_target)
    restore_method(Namer, :new_config_name, :orig_name)

    super # Вызывает базовый teardown для очистки папок на диске
  end

  # --- ТЕСТЫ ---

  def test_initialize_sets_correct_directories
    assert_equal '/mock/source', @copier.source_dir
    assert_equal '/mock/target', @copier.target_dir
  end

  def test_set_path_joins_directory_and_file
    assert_equal '/mock/source/file.conf', @copier.set_path('/mock/source', 'file.conf')
  end

  def test_copy_exits_if_source_file_does_not_exist
    File.stub :exist?, false do
      # Теперь метод сразу бросает ArgumentError наружу
      assert_raises(ArgumentError) do
        @copier.copy('missing.conf', 'target.conf')
      end
    end
  end

  def test_copy_calls_system_copy_when_file_exists
    # Мокаем существование файла и системный вызов
    File.stub :exist?, true do
      # Проверяем, что system_copy вызывается с правильными аргументами
      mock_system_copy = lambda { |src, tgt|
        assert_equal '/mock/source/amnezia.conf', src
        assert_equal '/mock/target/target.conf', tgt
        true # Возвращаем true (успешное копирование)
      }

      @copier.stub :system_copy, mock_system_copy do
        result = nil
        capture_io { result = @copier.copy('amnezia.conf', 'target.conf') }
        assert result
      end
    end
  end

  def test_rename_and_copy_uses_namer_if_target_is_nil
    File.stub :exist?, true do
      @copier.stub :system_copy, true do
        result = nil
        capture_io { result = @copier.rename_and_copy('amnezia.conf') }
        assert_equal 'mocked_amnezia.conf', result
      end
    end
  end

  def test_rename_and_copy_uses_provided_target
    File.stub :exist?, true do
      @copier.stub :system_copy, true do
        result = nil
        capture_io { result = @copier.rename_and_copy('amnezia.conf', 'custom.conf') }
        assert_equal 'custom.conf', result
      end
    end
  end
end
