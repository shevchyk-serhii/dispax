#!/usr/bin/env ruby
# One-off helper that adds the `RunnerUITests` UI Testing Bundle target to the
# Xcode project, wired to the `Runner` app target, for Patrol native automation.
#
# Idempotent: re-running it is a no-op if the target already exists.
#
#   ruby ios/add_patrol_uitests_target.rb
#
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

target_name = 'RunnerUITests'

if project.targets.any? { |t| t.name == target_name }
  puts "Target '#{target_name}' already exists — nothing to do."
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found" unless runner

# Create the UI test bundle target.
ui_test_target = project.new_target(
  :ui_test_bundle,
  target_name,
  :ios,
  '14.0',
  project.products_group,
  :swift
)

# Add the Swift sources.
group = project.main_group.find_subpath(target_name, true)
group.set_source_tree('SOURCE_ROOT')
%w[RunnerUITests.swift].each do |file|
  ref = group.new_reference(File.join(target_name, file))
  ui_test_target.add_file_references([ref])
end

# Build settings: bundle id, Info.plist, deployment target, test host.
ui_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.shevchyk.web.#{target_name}"
  config.build_settings['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['TEST_TARGET_NAME'] = 'Runner'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['DEVELOPMENT_TEAM'] =
    runner.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
end

# Make RunnerUITests depend on Runner so the app is built/installed first.
ui_test_target.add_dependency(runner)

# Register the target in the default scheme's test action so `patrol`/xcodebuild find it.
project.save
puts "Added '#{target_name}' UI test target to #{project_path}"
