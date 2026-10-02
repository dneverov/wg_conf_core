require_relative 'unit_test_case'

class VpnPingerTest < UnitTestCase
  setup_unit_paths 'pinger'

  def test_ping_all_returns_empty_array_if_no_configs
    assert_empty VpnPinger.ping_all
  end

  def test_ping_all_checks_every_available_interface
    create_mock_config(TXT_MOCK_DIR, 'wg2_rus_mos.conf')
    create_mock_config(TXT_MOCK_DIR, 'wg2_chi_san.conf')

    # Включаем симуляцию успешного прохождения пинга
    results = with_stubbed_ping(true) { VpnPinger.ping_all }

    assert_equal 2, results.size

    assert_equal 'wg2_chi_san', results[0][:interface]
    assert_equal true, results[0][:active]

    assert_equal 'wg2_rus_mos', results[1][:interface]
    assert_equal true, results[1][:active]
  end

  def test_ping_all_handles_failed_interfaces
    create_mock_config(TXT_MOCK_DIR, 'wg2_broken.conf')

    # Включаем симуляцию сбоя сети или блокировки ТСПУ
    results = with_stubbed_ping(false) { VpnPinger.ping_all }

    assert_equal 1, results.size
    assert_equal 'wg2_broken', results[0][:interface]
    assert_equal false, results[0][:active]
  end

  private

    # Перехватываем выполнение системных команд как в инспекторе, так и в раннере
    def with_stubbed_ping(value, &block)
      VpnInspector.stub(:execute_command, value) do
        VpnRunner.stub(:execute_command, value) do
          Config.silence_output(&block)
        end
      end
    end
end
