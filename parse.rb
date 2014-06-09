require 'csv'
require 'uri'
require 'logger'

file = File.open('parser.log', File::WRONLY | File::CREAT | File::TRUNC)
logger = Logger.new(file)


@goods = {}
CSV.foreach("export.csv", encoding: "UTF-8") do |row|
  @goods[row[1]] = {article: row[2], name: row[0]}
end
logger.info { "Товаров из Битрикса #{@goods.count}" }

@items = []

Dir.foreach('files') do |item|
  if item == '.' or item == '..' or item =~ /\A\.+/
    logger.info { "Пропустим файл #{item}" }
    next
  end
  logger.info { "Парсим файл #{item}" }

  @is_description = false
  File.read("files/#{item}").force_encoding("cp1251").encode("utf-8", undef: :replace).each_line do |line|
    next if line =~ /\A(\s)+\z/ or line =~ /\A(\d){1,2}\r\n\z/

    if line =~ URI::regexp
      uris = URI.extract line
      uri = URI.parse uris.first if uris
      path = uri.path if uri
      keyword = path.split('/').last if path
      good = @goods[keyword]
      if good
        @items << good
        @is_description = true
        logger.info { "Добавили позицию #{good}" }
      else
        logger.error { "Битый урл #{item}" }
      end
    elsif line =~ /\A(?<article>\d+-?\d{0,})(\s){0,}(?<name>.*\r\n)\z/
      good = {article: Regexp.last_match[:article], name: Regexp.last_match[:name]}
      @items << good
      @is_description = true
      logger.info { "Добавили позицию #{good}" }
    elsif @is_description
      @items.last[:description] ||= ''
      @items.last[:description] << line
      # @is_description = false
      logger.info { "Добавили описание к позиции #{line[0..50]}…" }
    end
  end
end
logger.info { "Всего #{@items.count} позиций" }

column_names = @items.first.keys
s=CSV.open 'result.csv', 'w', {col_sep: ';'} do |csv|
  csv << column_names
  @items.each do |x|
    csv << x.values
  end
end