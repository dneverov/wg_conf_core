require_relative 'unit_test_case'

class VpnListerTest < UnitTestCase
  setup_unit_paths 'lister'

  def test_returns_friendly_message_if_directory_is_empty
    assert_raises(RuntimeError) do
      VpnLister.render
    end
  end

  def test_render_raises_permission_error_when_directory_is_not_readable
    # Получаем путь к текущей тестовой директории моков
    test_target_dir = Config.target_dir

    # Мокаем File.readable? именно для этой папки
    File.stub(:readable?, ->(dir) { dir == test_target_dir ? false : true }) do

      assert_raises(Errno::EACCES) do
        VpnLister.render
      end

    end
  end

  def test_sorts_by_name_vertical_columns
    create_mock_config(TXT_MOCK_DIR, 'wg2_rus_mos.conf')
    create_mock_config(TXT_MOCK_DIR, 'wg2_chi_san.conf')
    create_mock_config(TXT_MOCK_DIR, 'wg2_aut_vie.conf')
    create_mock_config(TXT_MOCK_DIR, 'wg2_deu_fra.conf')

    output = VpnLister.render(sort_by: :name)

    # Алфавитный массив: [aut_vie, chi_san, deu_fra, rus_mos]
    # При 4 элементах и row_count = 2:
    # Строка 0 (idx 0, idx 2) -> aut_vie, deu_fra
    # Строка 1 (idx 1, idx 3) -> chi_san, rus_mos
    lines = output.split("\n")
    assert_equal "wg2_aut_vie   wg2_deu_fra", lines[0].strip
    assert_equal "wg2_chi_san   wg2_rus_mos", lines[1].strip
  end

  def test_sorts_by_time_vertical_columns
    create_mock_config(TXT_MOCK_DIR, 'wg2_old.conf', days_old: 5)
    create_mock_config(TXT_MOCK_DIR, 'wg2_fresh.conf', days_old: 0)
    create_mock_config(TXT_MOCK_DIR, 'wg2_medium.conf', days_old: 2)
    create_mock_config(TXT_MOCK_DIR, 'wg2_newer.conf', days_old: 1)

    output = VpnLister.render(sort_by: :time)

    # Массив по времени: [fresh, newer, medium, old]
    # При 4 элементах и row_count = 2:
    # Строка 0 (idx 0, idx 2) -> fresh, medium
    # Строка 1 (idx 1, idx 3) -> newer, old
    lines = output.split("\n")
    assert_equal "wg2_fresh    wg2_medium", lines[0].strip
    assert_equal "wg2_newer    wg2_old", lines[1].strip
  end

  def test_sorts_by_time_with_verbose_dates_in_two_columns
    # Создаем конфигурации с разным возрастом через встроенный хелпер
    create_mock_config(TXT_MOCK_DIR, 'wg2_fresh.conf', days_old: 0)
    create_mock_config(TXT_MOCK_DIR, 'wg2_old.conf',   days_old: 1)

    output = VpnLister.render(sort_by: :time, verbose_time: true)

    # Динамически вычисляем ожидаемые даты для проверки
    fresh_date = Time.now.strftime('%Y-%m-%d')
    old_date   = (Time.now - 86400).strftime('%Y-%m-%d')

    # Проверяем структуру вывода в две колонки по времени (свежие выше)
    assert_match(/wg2_fresh\s+#{fresh_date}\s+\d{2}:\d{2}.*wg2_old\s+#{old_date}\s+\d{2}:\d{2}/, output)
  end
end
