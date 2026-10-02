require_relative 'unit_test_case'

class FileCopierTest < UnitTestCase
  # Генерирует константы TEST_DIR, CONFIG_FILE, SRC_MOCK_DIR и TXT_MOCK_DIR
  setup_unit_paths 'file_copier'

  # --- ТЕСТЫ ---

  # TODO: Update also for supported types (without renaming)
  def test_successfully_copies_supported_files
    # 1. Создаем фейковые файлы конфигураций в папке-источнике
    create_mock_config(SRC_MOCK_DIR, 'UnitedKingdomLondonS3.conf', content: 'dummy content')
    create_mock_config(SRC_MOCK_DIR, 'ChileSantiago.conf',         content: 'dummy conf')
    create_mock_config(SRC_MOCK_DIR, 'USANewYorkCityS2.png',       content: 'not a config') # Этот файл копироваться НЕ должен

    # 2. Запускаем метод синхронизации
    assert execute_sync

    # 3. Проверяем, что нужные файлы скопировались, а лишние — нет
    assert File.exist?(File.join(TXT_MOCK_DIR, 'wg2_UK_lon_S3.conf'))
    assert File.exist?(File.join(TXT_MOCK_DIR, 'wg2_chi_san.conf'))
    refute File.exist?(File.join(TXT_MOCK_DIR, 'wg2_USA_new_S2.png')), "Файлы картинок не должны копироваться"
  end

  def test_raises_error_if_source_directory_does_not_exist
    # Удаляем исходную папку, чтобы вызвать ошибку
    FileUtils.rm_rf(SRC_MOCK_DIR)

    assert_raises(RuntimeError) do
      execute_sync
    end
  end

  def test_raises_error_if_target_directory_does_not_exist
    # Удаляем целевую папку, чтобы вызвать ошибку
    FileUtils.rm_rf(TXT_MOCK_DIR)

    assert_raises(RuntimeError) do
      execute_sync
    end
  end

  # --- НОВЫЕ ТЕСТЫ ДЛЯ ПЕРИОДОВ ВРЕМЕНИ ---

  def test_filters_files_by_period_today
    # Создаем один сегодняшний файл и один старый (5 дней назад)
    create_mock_config(SRC_MOCK_DIR, 'ChileSantiago.conf',         content: 'today')
    create_mock_config(SRC_MOCK_DIR, 'UnitedKingdomLondonS3.conf', content: 'old', days_old: 5)

    # Запускаем для "0" (сегодня)
    assert execute_sync("0")

    # Сегодняшний должен скопироваться, старый — нет
    assert File.exist?(File.join(TXT_MOCK_DIR, 'wg2_chi_san.conf'))
    refute File.exist?(File.join(TXT_MOCK_DIR, 'wg2_UK_lon_S3.conf'))
  end

  def test_filters_files_by_period_integer_days
    create_mock_config(SRC_MOCK_DIR, 'ChileSantiago.conf',         content: '3 days', days_old: 3)
    create_mock_config(SRC_MOCK_DIR, 'UnitedKingdomLondonS3.conf', content: '5 days', days_old: 5)

    # Ищем файлы за последние 4 дня
    assert execute_sync("4")

    # Файл 3-дневной давности копируется, 5-дневной — игнорируется
    assert File.exist?(File.join(TXT_MOCK_DIR, 'wg2_chi_san.conf'))
    refute File.exist?(File.join(TXT_MOCK_DIR, 'wg2_UK_lon_S3.conf'))
  end

  def test_copies_all_files_when_period_is_all
    # 100 дней назад
    create_mock_config(SRC_MOCK_DIR, 'ChileSantiago.conf', content: 'old', days_old: 100)

    # С параметром "all" дата не важна
    assert execute_sync("all")
    assert File.exist?(File.join(TXT_MOCK_DIR, 'wg2_chi_san.conf'))
  end

  def test_exits_with_error_on_invalid_period_argument
    assert_raises(ArgumentError) do
      FileCopier.sync!(period_arg: 'invalid_param')
    end
  end

  def test_continues_copying_if_one_file_fails
    # Выясняем, какой именно путь для моков настроен внутри класса Copier
    test_target_dir = Copier.new.target_dir

    create_mock_config(SRC_MOCK_DIR, 'UnitedKingdomLondonS3.conf')
    create_mock_config(SRC_MOCK_DIR, 'ChileSantiago.conf')

    mock_copier = Copier.new

    mock_copier.stub(:rename_and_copy, ->(name) {
      if name == 'UnitedKingdomLondonS3.conf'
        raise "Simulated copy error"
      else
        # Определяем путь, используя реальную целевую директорию копировщика
        target_path = File.join(test_target_dir, "mocked_#{name}")
        FileUtils.touch(target_path)
        "mocked_#{name}"
      end
    }) do

      Copier.stub(:new, mock_copier) do
        results = FileCopier.sync!(period_arg: 'all')

        assert_equal 2, results.size

        london_res = results.find { |r| r[:file] == 'UnitedKingdomLondonS3.conf' }
        refute_nil london_res
        refute london_res[:success]
        assert_match(/Simulated copy error/, london_res[:error])

        chile_res = results.find { |r| r[:file] == 'ChileSantiago.conf' }
        refute_nil chile_res
        assert chile_res[:success]

        expected_path = File.join(test_target_dir, 'mocked_ChileSantiago.conf')
        assert_equal expected_path, chile_res[:target_path]

        # Используем динамически полученную директорию для проверок на диске
        assert File.exist?(File.join(test_target_dir, 'mocked_ChileSantiago.conf')),
               "Успешный файл должен физически существовать в целевой директории"

        refute File.exist?(File.join(test_target_dir, 'mocked_UnitedKingdomLondonS3.conf')),
               "Файл с ошибкой копирования не должен создаваться в целевой директории"
      end
      # // Copier.stub
    end
  end
  # // test_continues_copying_if_one_file_fails

  def test_sync_handles_system_copy_failures_due_to_permissions
    # Готовим тестовый конфиг в исходной папке
    create_mock_config(SRC_MOCK_DIR, 'ChileSantiago.conf')

    mock_copier = Copier.new

    # Симулируем поведение класса Copier при ошибке записи (теперь он бросает RuntimeError)
    mock_copier.stub(:rename_and_copy, ->(_name) {
      raise RuntimeError, "System copy failed (check write permissions)"
    }) do

      Copier.stub(:new, mock_copier) do
        results = FileCopier.sync!(period_arg: 'all')

        assert_equal 1, results.size

        file_res = results.first
        # Проверяем, что FileCopier зафиксировал ошибку, а не ложный успех
        refute file_res[:success], "Файл не должен помечаться как успешный при сбое cp"
        assert_match(/System copy failed/, file_res[:error])
      end

    end
    # // mock_copier.stub
  end
  # // test_sync_handles_system_copy_failures_due_to_permissions

  private

    # A wrapper method for the `FileCopier.sync!`
    def execute_sync(period_arg = "0")
      # Перенаправляем стандартный вывод в "виртуальную строку"
      original_stdout = $stdout
      captured_stdout = StringIO.new
      $stdout = captured_stdout

      # Вызываем оригинальный метод и сохраняем его результат
      result = FileCopier.sync!(period_arg: period_arg)

      # ЕСЛИ в тест передан блок, отдаем туда строку с выводом консоли
      yield(captured_stdout.string) if block_given?

      result
    ensure
      # Гарантированно возвращаем поток вывода системе, даже если sync! выбросит ошибку
      $stdout = original_stdout
    end
end
