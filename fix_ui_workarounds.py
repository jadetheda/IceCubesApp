import os
import glob

def replace_in_file(path, old, new):
    if not os.path.exists(path): return
    with open(path, 'r') as f:
        text = f.read()
    if old in text:
        text = text.replace(old, new)
        with open(path, 'w') as f:
            f.write(text)

replace_in_file('Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift', '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons')
replace_in_file('Packages/Account/Sources/Account/Detail/AccountDetailContextMenu.swift', '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowBoostsButton', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowBoostsButton')

replace_in_file('Packages/Account/Sources/Account/Follow/FollowButton.swift', '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons')
replace_in_file('Packages/Account/Sources/Account/Follow/FollowButton.swift', '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowBoostsButton', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowBoostsButton')

replace_in_file('Packages/Timeline/Sources/Timeline/View/TimelineTagHeaderView.swift', '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons')
replace_in_file('Packages/Explore/Sources/Explore/ExploreView.swift', '!preferences.useIceShrimpWorkarounds || preferences.iceShrimpShowIncompatibleButtons', '!client.isIceShrimpWorkaroundsEnabled || preferences.iceShrimpShowIncompatibleButtons')

# TimelineFilter
replace_in_file('Packages/Timeline/Sources/Timeline/TimelineFilter.swift', 'UserPreferences.shared.tagGroupsClientSideMergeEnabled, UserPreferences.shared.useIceShrimpWorkarounds', 'UserPreferences.shared.tagGroupsClientSideMergeEnabled /* useIceShrimpWorkarounds */')

# NotificationsListDataSource
replace_in_file('Packages/Notifications/Sources/Notifications/List/NotificationsListDataSource.swift', 'if UserPreferences.shared.useIceShrimpWorkarounds && !UserPreferences.shared.iceShrimpShowIncompatibleButtons {', 'if client.isIceShrimpWorkaroundsEnabled && !UserPreferences.shared.iceShrimpShowIncompatibleButtons {')

# ListAddAccountViewModel
replace_in_file('Packages/Lists/Sources/Lists/AddAccounts/ListAddAccountViewModel.swift', 'guard UserPreferences.shared.useIceShrimpWorkarounds else {', 'guard client.isIceShrimpWorkaroundsEnabled else {')

