cat Packages/Timeline/Sources/Timeline/actors/TimelineDatasource.swift | awk '
/var isSeen = seen\?\.contains\(status.id\) \?\? false/ {
  print
  in_isSeen=1
  next
}
in_isSeen && /if hideSeenPostsIncludeBoosts, let reblog = status.reblog \{/ {
  print
  getline; print
  getline; print
  getline; print
  getline; print
  print "    if status.account.id == CurrentAccount.shared.account?.id {"
  print "      isSeen = true"
  print "    }"
  in_isSeen=0
  next
}
in_isSeen && /if status.account.id == CurrentAccount.shared.account\?\.id \{/ {
  getline
  getline
  next
}
{print}
' > temp_ds3.swift && mv temp_ds3.swift Packages/Timeline/Sources/Timeline/actors/TimelineDatasource.swift
