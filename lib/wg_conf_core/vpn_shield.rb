# frozen_string_literal: true

require_relative 'system_executor'
require_relative 'vpn_config_parser'

class VpnShield
  extend SystemExecutor

  class << self
    def enable!(config_name)
      server_ip = VpnConfigParser.extract_endpoint_ip(config_name)
      puts "Активация Kill Switch для сервера #{server_ip}..."

      # 1. Сбрасываем старые правила Kill Switch, если они были, чтобы не дублировать
      disable!

      # 2. Создаем кастомную цепочку в iptables для изоляции наших правил
      execute_command("iptables -N WG_KILL_SWITCH 2>/dev/null")
      execute_command("iptables -I OUTPUT -j WG_KILL_SWITCH")

      # 3. РАЗРЕШАЕМ: Локальный трафик (localhost)
      execute_command("iptables -A WG_KILL_SWITCH -o lo -j ACCEPT")

      # 4. РАЗРЕШАЕМ: Трафик до самого VPN-сервера (чтобы туннель мог дышать)
      execute_command("iptables -A WG_KILL_SWITCH -d #{server_ip} -j ACCEPT")

      # 5. РАЗРЕШАЕМ: Весь трафик, который идет ВНУТРИ VPN-интерфейса
      # Мы разрешаем выпуск трафика через интерфейс, имя которого совпадает с config_name
      execute_command("iptables -A WG_KILL_SWITCH -o #{config_name} -j ACCEPT")

      # 6. БЛОКИРУЕМ: Все остальное, что пытается выйти в обход VPN
      execute_command("iptables -A WG_KILL_SWITCH -j DROP")

      puts "Kill Switch успешно активирован. Трафик защищен."
    end

    def disable!
      # Проверяем, существует ли наша цепочка, чтобы не сыпать ошибками в консоль
      if execute_command("iptables -C OUTPUT -j WG_KILL_SWITCH 2>/dev/null")
        execute_command("iptables -D OUTPUT -j WG_KILL_SWITCH")
      end

      # Очищаем и удаляем кастомную цепочку
      execute_command("iptables -F WG_KILL_SWITCH 2>/dev/null")
      execute_command("iptables -X WG_KILL_SWITCH 2>/dev/null")
    end
  end
end
