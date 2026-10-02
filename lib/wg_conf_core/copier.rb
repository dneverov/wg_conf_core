require_relative 'config'
require_relative 'namer'

class Copier
  attr_reader :source_dir, :target_dir

  def initialize
    @source_dir = Config.source_dir
    @target_dir = Config.target_dir
  end

  def set_path(dir, file)
    "#{dir}/#{file}"
  end

  def copy(source, target)
    source_path = set_path(source_dir, source)
    target_path = set_path(target_dir, target)

    unless File.exist?(source_path)
      raise ArgumentError, "File #{source_path} not found!"
    end

    # Проверяем статус системной команды cp
    unless system_copy(source_path, target_path)
      raise RuntimeError, "System copy failed (check write permissions for #{target_dir})"
    end

    true
  end

  def rename_and_copy(source, target = nil)
    target ||= Namer.new_config_name(source)
    target if copy(source, target)
  end

  private

    def system_copy(source_path, target_path)
      system('cp', source_path, target_path)
    end
end
