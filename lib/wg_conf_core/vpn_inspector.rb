require_relative 'config'
require_relative 'system_executor'

class VpnInspector
  extend SystemExecutor # Подмешивает execute_command и read_system_output

  class << self
    # Проверяет активность сервиса И реальное прохождение трафика через него
    def connection_active?
      interface = active_interface_name
      return false if interface.nil?

      ping_successful?(interface)
    end

    # Собирает полную карту состояния VPN для развернутого вывода
    def detailed_status
      interface = active_interface_name

      {
        vpn_service:     Config.vpn_service,
        service_active:  service_active?,
        interface_name:  interface,
        ping_host:       Config.ping_host,
        ping_successful: interface ? ping_successful?(interface) : false
      }
    end

    # 3. Шаг инспекции: Проверочный пинг хоста через конкретный туннель
    def ping_successful?(interface)
      # -c 1 (один пакет), -W 2 (таймаут 2 секунды, если ТСПУ глушит пакеты)
      execute_command("ping -c 1 -W 2 -I #{interface} #{Config.ping_host} > /dev/null 2>&1", silent: true)
    end

    private

      # 1. Шаг инспекции: Проверка статуса службы в systemd
      def service_active?
        # Перенаправляем stdout/stderr в /dev/null, чтобы команда не мусорила в консоль
        execute_command("systemctl is-active '#{Config.vpn_service}*' > /dev/null 2>&1", silent: true)
      end

      # 2. Шаг инспекции: Поиск и парсинг имени активного интерфейса
      def active_interface_name
        return nil unless service_active?

        # Пытаемся динамически узнать имя поднятого интерфейса.
        # systemctl status выведет что-то вроде "awg-quick@wg2_rus_mos_K5.service"
        # Мы вытаскиваем то, что идет после знака @
        status_output = read_system_output("systemctl list-units '#{Config.vpn_service}*' --state=active")
        status_output.match(/#{Config.vpn_service}([^\s\.]+)/)&.captures&.first
      end
  end
end
