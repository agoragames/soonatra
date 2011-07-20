require 'dm-core'
require 'feedzirra-redis'
DataMapper.setup(:default, {:adapter => 'redis'})

namespace :blog do
  desc 'Update the latest blog posts to display'
  task :update do
    require './coming_soon'
    feed = FeedzirraRedis::Feed.first_or_create(
      :feed_url => ComingSoon::APP_CONFIG['blog_rss_url']
    )
    original_count = feed.entries.size
    feed = FeedzirraRedis::Feed.update(feed)
    new_count = feed.entries.size
    puts "#{new_count - original_count} entries added, total #{new_count}"
  end

  task :clear do
    require './coming_soon'
    original_count = FeedzirraRedis::Entry.count
    FeedzirraRedis::Entry.all.destroy
    new_count = FeedzirraRedis::Entry.count
    puts "#{original_count} entries destroyed, #{new_count} remain"
  end
end

namespace :concept do
  desc 'Generate small and thumbnail versions of concepts/*_large.png for the current theme'
  task :thumbs do
    require 'imanip'

    # Which theme to generate concepts for?
    File.read('views/themes/_current_theme.sass').scan(/@import themes\/(.*)/)
    current_theme = $1
    dir = File.expand_path(File.join(File.dirname(__FILE__), 'public', 'images', 'themes', current_theme, 'concepts'))
    Dir[File.join(dir, '*_large.png')].each do |large_path|
      dimensions = {:thumb => [200, 150], :small => [100, 75]}
      name = File.basename(large_path).gsub('_large.png','')
      image = Imanip::Image.new(large_path)
      dimensions.each do |size, w_h|
        puts "resizing #{name} to #{size}"
        image.resize(File.join(dir, "#{name}_#{size}.png"), :dimensions => w_h)
      end
    end
  end
end

namespace :theme do
  desc 'Set the current theme to use'
  task :set, :theme_name do |t, args|
    File.open('views/themes/_current_theme.sass', 'w') do |f|
      f.write "@import themes/#{args.theme_name}"
    end
    puts "Theme '#{args.theme_name}' activated."
  end

  desc 'Display the current theme'
  task :current do
    begin
      File.read('views/themes/_current_theme.sass').scan(/@import themes\/(.*)/)
      puts $1
    rescue
      puts "No current theme! Use 'rake theme:set[default]' to set one"
    end
  end

  desc 'Generate a new theme based on default'
  task :new, :theme_name do |t, args|
    puts 'Cloning default images directory...'
    system("mkdir -v public/images/themes/#{args.theme_name}")
    system("cp -vR public/images/themes/default/* public/images/themes/#{args.theme_name}")
    puts 'Cloning default stylesheets...'
    system("cp -v views/themes/_default.sass views/themes/_#{args.theme_name}.sass")
    puts 'Theme created!'
    system("rake theme:set[#{args.theme_name}]")
    puts "Add image assets to public/images/themes/#{args.theme_name}/"
    puts "Modify your Sass styles at views/themes/_#{args.theme_name}.sass"
  end

end
