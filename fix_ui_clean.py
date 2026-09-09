import os

def replace_in_file(path, old, new):
    if not os.path.exists(path): return
    with open(path, 'r') as f:
        text = f.read()
    if old in text:
        text = text.replace(old, new)
        with open(path, 'w') as f:
            f.write(text)

# We previously replaced:
# '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowIncompatibleButtons'
# with
# '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons'
# So we now want to just check !client.isIceShrimpWorkaroundsEnabled.

replace_in_file('Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled')
replace_in_file('Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowBoostsButton', '!client.isIceShrimpWorkaroundsEnabled')

replace_in_file('Packages/Account/Sources/Account/Follow/FollowButton.swift', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled')
replace_in_file('Packages/Account/Sources/Account/Follow/FollowButton.swift', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowBoostsButton', '!client.isIceShrimpWorkaroundsEnabled')

replace_in_file('Packages/Timeline/Sources/Timeline/View/TimelineTagHeaderView.swift', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled')
replace_in_file('Packages/Explore/Sources/Explore/ExploreView.swift', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled')

# NotificationsListDataSource
replace_in_file('Packages/Notifications/Sources/Notifications/List/NotificationsListDataSource.swift', 'if client.isIceShrimpWorkaroundsEnabled && !UserPreferences.shared.iceShrimpShowIncompatibleButtons {', 'if client.isIceShrimpWorkaroundsEnabled {')

# TimelineFilter
replace_in_file('Packages/Timeline/Sources/Timeline/TimelineFilter.swift', 'UserPreferences.shared.tagGroupsClientSideMergeEnabled /* useIceShrimpWorkarounds */', 'client.isIceShrimpWorkaroundsEnabled')

# MediaUIView and StatusRowMediaPreviewView
replace_in_file('Packages/MediaUI/Sources/MediaUI/MediaUIView.swift', 'let noVideo = Env.UserPreferences.shared.neverLoadVideo', 'let noVideo = false')
replace_in_file('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift', 'let noVideo = userPreferences.neverLoadVideo', 'let noVideo = false')
replace_in_file('Packages/StatusKit/Sources/StatusKit/Row/Subviews/StatusRowMediaPreviewView.swift', 'let noVideo = Env.UserPreferences.shared.neverLoadVideo', 'let noVideo = false') # just in case

