require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  next unless target.name == 'Runner'
  
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
    puts "Updated #{config.name} configuration for target #{target.name}"
  end
end

project.save
puts "Xcode project saved successfully."
