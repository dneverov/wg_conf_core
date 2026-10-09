# frozen_string_literal: true

require_relative 'test_helper'

class VpnConfigParserTest < Minitest::Test
  def setup
    super
    @mock_dir = File.join(__dir__, 'test_files_config_parser')
    FileUtils.mkdir_p(@mock_dir)

    # Временно подменяем target_dir на нашу тестовую папку
    Config.stub(:target_dir, @mock_dir) do
      # Создаем фейковый .conf файл с Endpoint
      @conf_content = <<~CONF
        [Interface]
        PrivateKey = dummy_key
        Address = 10.0.0.2/24

        [Peer]
        PublicKey = dummy_peer_key
        Endpoint = 198.51.100.42:51820
      CONF

      File.write(File.join(@mock_dir, 'test_vpn.conf'), @conf_content)
    end
  end

  def teardown
    FileUtils.rm_rf(@mock_dir)
    super
  end

  def test_extract_endpoint_ip_returns_correct_ip
    Config.stub(:target_dir, @mock_dir) do
      ip = VpnConfigParser.extract_endpoint_ip('test_vpn')
      assert_equal '198.51.100.42', ip
    end
  end
end
