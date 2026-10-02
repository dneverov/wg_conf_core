module SystemExecutor
  # Обертка для мутирующих команд (system)
  def execute_command(cmd, silent: false)
    if ENV['TEST_ENV'] == 'true'
      return false if ENV['MOCK_VPN_FAIL'] == 'true'

      # Выводим в stdout только если не включен тихий режим
      puts "[EXEC] #{cmd}" unless silent
      return true
    end
    system(cmd)
  end

  # Обертка для инспектирующих команд (бэктики)
  def read_system_output(cmd)
    if ENV['TEST_ENV'] == 'true'
      return "" if ENV['MOCK_VPN_FAIL'] == 'true'
      return "awg-quick@wg2_mock_interface.service loaded active running"
    end
    `#{cmd}`
  end
end
