platform :ios, '7.0'

inhibit_all_warnings!

pod 'PeerTalk', :head
pod 'RESideMenu', :head

target :UnitTests, exclusive: true do
   pod 'Specta'
   pod 'Expecta'
end

target 'IntegrationTests' do
  pod 'Specta'
  pod 'KIF', :head
end
