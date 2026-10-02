require_relative 'unit_test_case'

class VpnRunnerTest < UnitTestCase
  setup_unit_paths 'vpn'

  # Для обратной совместимости со старыми тестами
  TARGET_MOCK = TXT_MOCK_DIR

  # Переопределяем метод run, чтобы автоматически выполнять каждый тест "в тишине"
  def run(*args, &block)
    Config.silence_output { super }
  end

  def setup
    super # Вызываем базовый setup для создания папок

    # 1. Безопасно глушим Config
    replace_method(Config, :target_dir, :orig_target) { TARGET_MOCK }

    # 2. Глушим execute_command у VpnRunner
    @executed_commands = []

    # Создаем ЛОКАЛЬНУЮ переменную. Она гарантированно пробросится внутрь блока class_eval
    commands_array = @executed_commands 

    replace_method(VpnRunner, :execute_command, :orig_execute) do |cmd, **options|
      commands_array << cmd # Пишем в локальную переменную, контекст её видит!
      true
    end
  end

  def teardown
    # 3. Восстанавливаем оригинальные методы из файлов lib/
    restore_method(Config, :target_dir, :orig_target)
    restore_method(VpnRunner, :execute_command, :orig_execute)

    super # Вызываем базовый teardown для очистки папок
  end

  # --- ТЕСТЫ ---

  def test_runs_with_explicit_config_name
    assert VpnRunner.run!("wg2_chi_san.conf", show_status: true)

    assert_includes @executed_commands, "systemctl stop 'awg-quick@*'"
    assert_includes @executed_commands, "systemctl start awg-quick@wg2_chi_san.service"
    assert_includes @executed_commands, "awg show wg2_chi_san"
  end

  def test_automatically_picks_latest_config_if_none_provided
    old_file    = 'wg2_old_config.conf'
    latest_file = 'wg2_UK_lon_S3.conf'

    # Так как час — это 1/24 часть дня, передаем days_old как дробное число!
    create_mock_config(TARGET_MOCK, old_file,    days_old: 1.0/24)
    create_mock_config(TARGET_MOCK, latest_file, days_old: 0)

    assert VpnRunner.run!(show_status: true)

    assert_includes @executed_commands, "systemctl start awg-quick@wg2_UK_lon_S3.service"
    assert_includes @executed_commands, "awg show wg2_UK_lon_S3"
    refute_includes @executed_commands, "systemctl start awg-quick@wg2_old_config.service"
  end

  # Проверяем тихий режим по умолчанию (без флага -i)
  def test_does_not_show_status_by_default
    assert VpnRunner.run!("wg2_chi_san.conf") # Вызов по умолчанию без флагов

    assert_includes @executed_commands, "systemctl start awg-quick@wg2_chi_san.service"
    # Метод show_status не должен был вызываться, проверяем отсутствие команд диагностики
    refute_includes @executed_commands, "awg show wg2_chi_san"
    refute_includes @executed_commands, "wg show wg2_chi_san"
  end

  def test_returns_false_if_no_configs_found_and_no_argument_provided
    # Папка пустая, аргументов нет — ожидаем падение с RuntimeError
    assert_raises(RuntimeError) do
      VpnRunner.run!
    end

    assert_empty @executed_commands
  end

  def test_raises_error_if_systemctl_command_fails
    # Локально меняем поведение нашего фейкового метода на время одного теста
    VpnRunner.singleton_class.class_eval do
      remove_method :execute_command
      def execute_command(cmd)
        !cmd.include?('systemctl start')
      end
    end

    # Теперь мы ожидаем, что метод выбросит RuntimeError при сбое запуска
    assert_raises(RuntimeError) do
      VpnRunner.run!("wg2_chi_san")
    end
  ensure
    # Обязательно возвращаем базовую заглушку обратно для корректного teardown
    replace_method(VpnRunner, :execute_command, :orig_execute) do |cmd|
      @executed_commands << cmd
      true
    end
  end
end
