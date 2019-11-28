axios = require 'axios'

{
  parseISO
  addDays
  isBefore
} = require 'date-fns'

{
  sortBy
} = require 'underscore'

URL_REGEX = /(https?:\/\/[\w-/.]*)/
GCAL_KEY = "AIzaSyA-xW0xIfYvro-zD0JCLRfJwqs6s2MmKmU"
GCAL_IDS = [
  "tgh4uc5t6uhr4icjrcgqfhe18r2uu3fg@import.calendar.google.com"
  "11j5qfhbb916srru7kuae99i4rn3p8r5@import.calendar.google.com"
  "89aheia1si29mqt1kvuprggnid983m87@import.calendar.google.com"
  "sv5rg9q32cg6qhabdgi33fjur45vcilh@import.calendar.google.com"
  "3drnie5h5b5mr73acgcqpvvc2k@group.calendar.google.com"
  "torontojs.com_o83mhhuck726m114hgkk3hl79g@group.calendar.google.com"
  "59s1qmiqr7bo98uqkek5ba7er2eduk3t@import.calendar.google.com"
  "k6l8oiu416ftcjpjetn0r7a79me8pq4r@import.calendar.google.com"
  "h1tmhrt7ruckpk3ad20jaq55amvaiubu@import.calendar.google.com"
  "7i14k13k6h3a9opbokgmj63k1074gd78@import.calendar.google.com"
  "cmm8uhv8s34d21711h5faa4e3a34napd@import.calendar.google.com"
  "3usg04moak5e7qejj73mu9u05p2r3rer@import.calendar.google.com"
]

Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}

module.exports =
class Event
  constructor: (obj={})->
    @[key] = val for key, val of obj
    @

  @getter 'url', ->
    @description.match(URL_REGEX)?[1]

  @getter 'venue', ->
    @location.match(/(.*)\s\(/)?[1]

  @getter 'address', ->
    @location.match(/\((.*)\)/)?[1]

  @getter 'map_url', ->
    "https://www.google.com/maps/search/?api=1&query=#{@address.replace /\s+/g, '+'}"

  @getter 'host', ->
    @organizer.displayName.replace 'Events - ', ''

  @getter 'starts_at', ->
    parseISO @start?.dateTime

  @getter 'starts_at_stamp', ->
    Math.round @starts_at / 1000

  @getter 'ends_at', ->
    parseISO @end?.dateTime

  @getter 'is_confirmed', ->
    @status is 'confirmed'

  @getter 'is_future', ->
    isBefore Date.now(), @starts_at

  @getter 'is_this_week', ->
    @is_future and isBefore @starts_at, addDays Date.now(), 7

  @getter 'is_today', ->
    @is_future and isBefore @starts_at, addDays Date.now(), 1

  # https://api.slack.com/tools/block-kit-builder
  @getter 'slack_section', ->
    type: 'section'
    text:
      type: 'mrkdwn'
      text: """
        *#{@summary}*
        by #{@host}

        <!date^#{@starts_at_stamp}^{date_pretty} at {time}|#{@starts_at}>

        <#{@map_url}|#{@venue}>
      """
    accessory:
      type: "button"
      text:
        type: "plain_text"
        text: "Learn More"
        emoji: true
      value: @url


  @load_feeds: ->
    Promise.all GCAL_IDS.map (id)->
      try
        await axios.get "https://www.googleapis.com/calendar/v3/calendars/#{id}/events?singleEvents=true&key=#{GCAL_KEY}"
      catch
        Promise.resolve()

  @all: ->
    events = (await @load_feeds())
    .map (feed)-> feed?.data?.items or []
    .reduce (arr=[], items)->
      arr.push new Event item for item in items
      arr

    sortBy events, 'starts_at'

  @this_week: ->
    (evt for evt in (await Event.all()) when evt.is_confirmed and evt.is_this_week)

  @today: ->
    (evt for evt in (await Event.all()) when evt.is_confirmed and evt.is_today)