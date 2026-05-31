require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_target = project.targets.find { |t| t.name == 'VEffectWidgetExtension' }
if widget_target.nil?
  puts "Widget target not found"
  exit 1
end

widget_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'VEffectWidget/VEffectWidget.entitlements'
end

project.save
puts "Entitlements added to VEffectWidgetExtension"
