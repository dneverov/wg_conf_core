require_relative 'vpn_inspector'
require_relative 'vpn_runner'

class VpnPinger
  class << self
    def ping_all
      target_dir = Config.target_dir
      all_files  = Config.find_files(target_dir, '*.conf')
      return [] if all_files.empty?

      interfaces = all_files.map { |f| File.basename(f, '.conf') }.sort
      initial_interface = VpnInspector.send(:active_interface_name)
      results = []

      begin
        interfaces.each do |interface|
          switch_interface(interface)
          status = VpnInspector.ping_successful?(interface)
          result = { interface: interface, active: status }

          results << result
          # Если скрипт передал блок, отдаем ему промежуточный результат для печати на лету
          yield(result) if block_given?
        end
      ensure
        # Используем методы VpnRunner для восстановления сети
        if initial_interface
          switch_interface(initial_interface)
        else
          VpnRunner.stop_connections
        end
      end

      results
    end

    private

      def switch_interface(interface)
        return if ENV['TEST_ENV'] == 'true'

        VpnRunner.stop_connections
        # Передаем raise_on_fail: false, чтобы сбой systemctl не ронял пингер
        VpnRunner.start_connection(interface, raise_on_fail: false)
      end
  end
end
