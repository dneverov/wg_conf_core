require_relative 'unit_test_case'

class VpnInspectorTest < UnitTestCase
  setup_unit_paths 'inspector'

  def setup
    super

    @commands_executed = []
    commands_array = @commands_executed

    # Используем хэш в локальной переменной. Локальная переменная образует замыкание
    # и будет на 100% доступна внутри блока class_eval!
    mock_flags  = { service: true, ping: true }
    @mock_flags = mock_flags # Сохраняем ссылку, чтобы менять флаги из самих тест-методов

    # Принимаем и саму команду (cmd), и любые именованные аргументы (**options)
    replace_method(VpnInspector, :execute_command, :orig_execute) do |cmd, **options|
      commands_array << cmd

      if cmd.include?('systemctl is-active')
        mock_flags[:service]
      elsif cmd.include?('ping')
        mock_flags[:ping]
      else
        true
      end
    end

    # Вычисляем хелперы и сохраняем в локальные переменные
    prefix    = service_prefix
    interface = expected_interface

    # Используем хелперы service_prefix и expected_interface
    replace_method(VpnInspector, :read_system_output, :orig_read) do |cmd, **options|
      commands_array << cmd
      "#{prefix}#{interface}.service loaded active running"
    end
  end

  def teardown
    restore_method(VpnInspector, :execute_command, :orig_execute)
    restore_method(VpnInspector, :read_system_output, :orig_read)
    super
  end

  # --- ТЕСТЫ ---

  def test_returns_true_when_service_and_ping_are_successful
    assert VpnInspector.connection_active?

    assert_includes @commands_executed, "systemctl is-active '#{service_prefix}*' > /dev/null 2>&1"
    assert_includes @commands_executed, "systemctl list-units '#{service_prefix}*' --state=active"
    assert_includes @commands_executed, "ping -c 1 -W 2 -I #{expected_interface} #{Config.ping_host} > /dev/null 2>&1"
  end

  def test_returns_false_instantly_if_service_is_inactive
    # Меняем флаг в нашем общем хэше через сохранённую ссылку
    @mock_flags[:service] = false

    refute VpnInspector.connection_active?

    assert_includes @commands_executed, "systemctl is-active '#{service_prefix}*' > /dev/null 2>&1"
    refute_includes @commands_executed, "systemctl list-units '#{service_prefix}*' --state=active"
  end

  def test_returns_false_if_ping_fails_due_to_tspu_blocking
    # Симулируем, что служба активна, но пинг падает
    @mock_flags[:service] = true
    @mock_flags[:ping] = false

    refute VpnInspector.connection_active?

    assert_includes @commands_executed, "systemctl is-active '#{service_prefix}*' > /dev/null 2>&1"
    assert_includes @commands_executed, "ping -c 1 -W 2 -I #{expected_interface} #{Config.ping_host} > /dev/null 2>&1"
  end

  def test_detailed_status_returns_full_diagnostic_hash
    status = VpnInspector.detailed_status

    # Проверяем, что метод возвращает правильные ключи и типы данных
    assert_equal service_prefix, status[:vpn_service]
    assert_equal true, status[:service_active]
    assert_equal expected_interface, status[:interface_name]
    assert_equal Config.ping_host, status[:ping_host]
    assert_equal true, status[:ping_successful]
  end

  private

    # Тип VPN по умолчанию в коде
    def service_prefix
      Config.vpn_service # 'awg-quick@'
    end

    # Имя тестового интерфейса
    def expected_interface
      'wg2_rus_mos_K5'
    end
end
