class @UpdateNavigationController extends @NavigationController

  onAttach: ->
    @_request = ledger.fup.FirmwareUpdater.instance.requestFirmwareUpdate()
    @_request.on 'plug', => @_onPlugDongle()
    @_request.on 'unplug', =>  @_onDongleNeedPowerCycle()
    @_request.on 'stateChanged', (ev, data) => @_onStateChanged(data.newState, data.oldState)
    @_request.on 'needsUserApproval', @_onNeedsUserApproval
    @_request.onProgress @_onProgress.bind(@)
    ledger.fup.FirmwareUpdater.instance.load =>
    window.fup = @_request # TODO: REMOVE THIS

  onDetach: ->
    @_request.cancel()

  _onPlugDongle: ->
    ledger.app.router.go '/update/plug'

  _onErasingDongle: ->
    ledger.app.router.go '/update/erasing'

  _onDongleNeedPowerCycle: ->
    ledger.app.router.go '/update/unplug'

  _onReloadingBootloaderFromOs: ->
    ledger.app.router.go '/update/reloadblfromos'

  _onLoadingOs: ->
    ledger.app.router.go '/update/loados'

  _onLoadingBootloaderReloader: ->
    ledger.app.router.go '/update/loadrblreloader'

  _onLoadingBootloader: ->
    ledger.app.router.go '/update/loadbl'

  _onStateChanged: (newState, oldState) ->
    switch newState
      when ledger.fup.FirmwareUpdateRequest.States.Erasing then @_onErasingDongle()
      when ledger.fup.FirmwareUpdateRequest.States.ReloadingBootloaderFromOs then @_onReloadingBootloaderFromOs()
      when ledger.fup.FirmwareUpdateRequest.States.LoadingOs then @_onLoadingOs()
      when ledger.fup.FirmwareUpdateRequest.States.LoadingBootloaderReloader then @_onLoadingBootloaderReloader()
      when ledger.fup.FirmwareUpdateRequest.States.LoadingBootloader then @_onLoadingBootloader()

  _onNeedsUserApproval: ->
    if @topViewController()?.isRendered()
      @topViewController().onNeedsUserApproval()
    else
      @topViewController().once 'afterRender', => @topViewController().onNeedsUserApproval()

  _onProgress: (state, current, total) ->
    if @topViewController()?.isRendered()
      @topViewController().onProgress(state, current, total)
    else
      @topViewController().once 'afterRender', => @topViewController().onProgress(state, current, total)