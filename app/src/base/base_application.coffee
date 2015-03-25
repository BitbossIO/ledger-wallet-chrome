
@ledger ?= {}
ledger.base ?= {}
ledger.base.application ?= {}

###
  Base class for the main application class. This class holds the non-specific part of the application (i.e. click dispatching, application lifecycle)
###
class ledger.base.application.BaseApplication extends @EventEmitter

  constructor: ->
    @_navigationController = null
    @donglesManager = new ledger.dongle.Manager()
    @devicesManager = new DevicesManager()
    @walletsManager = new WalletsManager(this)
    @router = new Router(@)
    ledger.dialogs.manager.initialize($('#dialogs_container'))

  ###
    Starts the application by configuring the application environment, starting services and rendering view controllers
  ###
  start: ->
    configureApplication @
    @_listenClickEvents()
    @_listenWalletEvents()
    @_listenDongleEvents()
    @onStart()
    @devicesManager.start()
    @donglesManager.start()


  ###
    Reloads the whole application.
  ###
  reload: () ->
    @donglesManager.stop()
    @devicesManager.stop()
    chrome.runtime.reload()

  ###
    Handle URI navigation through the application. This allows to dispatch actions on view controllers and pushing view controllers
    in the current {NavigationController}
  ###
  navigate: (layoutName, viewController) ->
    @router.once 'routed', (event, data) =>
      oldUrl = if @_lastUrl? then @_lastUrl.parseAsUrl() else {hash: '', pathname: '', params: -> ''}
      newUrl = data.url.parseAsUrl()
      @_lastUrl = data.url
      @currentUrl = data.url
      controller = null

      ## Create action name and action parameters
      [actionName, parameters] = ledger.url.parseAction(newUrl.hash)

      onControllerRendered = () ->
        # Callback when the controller has been rendered
        @handleAction(actionName, parameters) if newUrl.hash.length > 0

      if @_navigationController == null or @_navigationController.constructor.name != layoutName
        @_navigationController?.onDetach()
        @_navigationController = new window[layoutName]()
        @_navigationController.onAttach()
        controller = new viewController(newUrl.params(), data.url)
        controller.on 'afterRender', onControllerRendered.bind(@)
        @_navigationController.push controller
        @_navigationController.render @_navigationControllerSelector()
      else
        if @_navigationController.topViewController().constructor.name == viewController.name and oldUrl.pathname == newUrl.pathname and _.isEqual(newUrl.params(), oldUrl.params()) # Check if only hash part of url change
          @handleAction(actionName, parameters)
        else
          controller = new viewController(newUrl.params(), data.url)
          controller.on 'afterRender', onControllerRendered.bind(@)
          @_navigationController.push controller

  ###
    Reloads the currently displayed view controller and css files.
  ###
  reloadUi: () ->
    $('link').each (_, link) ->
      if link.href? && link.href.length > 0
        cleanHref = link.href
        cleanHref = cleanHref.replace(/\?[0-9]*/i, '')
        link.href = cleanHref + '?' + (new Date).getTime()
    @_navigationController.render @_navigationControllerSelector() if @_navigationController?

  ###
    This method is used to dispatch an action to the view controller hierarchy. First it tries to trigger an action on
    open dialogs then it will attempt to trigger action on the navigation controller. The navigation controller will dispatch
    the action to its view controllers or handle the action itself. If the action is still unanswered at the end of the dispatch
    the application class can handle it itself.
  ###
  handleAction: (actionName, params) ->
    handled = no
    if ledger.dialogs.manager.displayedDialog()?
      handled = ledger.dialogs.manager.displayedDialog().handleAction actionName, params
    handled = @_navigationController.handleAction(actionName, params) unless handled
    handled

  ###
    Returns the jQuery element used as the main div container in which controllers will render themselves.

    @return [jQuery.Element] The jQuery element of the controllers container
  ###
  _navigationControllerSelector: -> $('#controllers_container')

  ###
    Catches click on links and dispatch them if possible to the router.
  ###
  _listenClickEvents: () ->
    self = @
    # Redirect every in-app link with our router
    $('body').delegate 'a', 'click', (e) ->
      if @href? and @protocol == 'chrome-extension:'
        url = null
        if  _.str.startsWith(@pathname, '/views/') and self.currentUrl?
          url = ledger.url.createRelativeUrlWithFragmentedUrl(self.currentUrl, @href)
        else
          url = @pathname + @search + @hash
        self.router.go url
        return no
      yes

    $('body').delegate '[data-href]', 'click', (e) ->
      href = $(this).attr('data-href')
      if href? and href.length > 0
        parser = href.parseAsUrl()
        if  _.str.startsWith(parser.pathname, '/views/') and self.currentUrl?
          url = ledger.url.createRelativeUrlWithFragmentedUrl(self.currentUrl, href)
        else
          url = parser.pathname + parser.search + parser.hash
        self.router.go url
        return no
      yes

  _listenWalletEvents: () ->
    # Wallet management & wallet events re-dispatching
    @walletsManager.on 'connecting', (event, card) => (Try => @onConnectingDongle(card)).printError()
    @walletsManager.on 'connected', (event, wallet) =>
      @wallet = wallet
      wallet.once 'disconnected', =>
        _.defer => (Try => @onDongleIsDisconnected(wallet)).printError()
        @wallet = null
      wallet.once 'unplugged', =>
        (Try => @onDongleNeedsUnplug(wallet)).printError()
      wallet.once 'state:unlocked', =>
        (Try => @onDongleIsUnlocked(wallet)).printError()
      (Try => @onDongleConnected(wallet)).printError()
      wallet.isDongleCertified (dongle, error) =>
        l arguments
        (Try => @onDongleCertificationDone(dongle, (if error? then no else yes))).printError()


  _listenDongleEvents: () ->
    # Dongle management & dongle events re-dispatching
    @donglesManager.on 'connected', (event, dongle) =>
      @dongle = dongle
      dongle.once 'disconnected', =>
        _.defer => (Try => @onDongleIsDisconnected(dongle)).printError()
        @dongle = null
      dongle.once 'state:error', =>
        (Try => @onDongleNeedsUnplug(dongle)).printError()
      dongle.once 'state:unlocked', =>
        (Try => @onDongleIsUnlocked(dongle)).printError()
      (Try => @onDongleConnected(dongle)).printError()

  onConnectingDongle: (card) ->

  onDongleConnected: (wallet) ->

  onDongleNeedsUnplug: (wallet) ->

  onDongleIsUnlocked: (wallet) ->

  onDongleIsDisconnected: (wallet) ->

  onDongleCertificationDone: (wallet, isCertified) ->