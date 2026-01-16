# Phase 7: Remaining Endpoints Implementation

## Status: 8 endpoints implemented, ~125 remaining

## Already Implemented
- [x] addReaction
- [x] getAllFriends
- [x] getGroupInfo
- [x] getUserInfo
- [x] sendMessage
- [x] sendSeenEvent
- [x] sendTypingEvent
- [x] uploadAttachment (Phase 6)
- [x] loginQR (Phase 6)

## Batch 1: Core Messaging (Priority: HIGH)
Essential for a functional chat client.

| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| sendSticker.ts | SendSticker | Medium | Uses sticker IDs |
| sendLink.ts | SendLink | Medium | URL preview/parsing |
| sendCard.ts | SendCard | Medium | Contact/business cards |
| sendVideo.ts | SendVideo | High | Uses uploadAttachment |
| sendVoice.ts | SendVoice | High | Audio upload |
| sendDeliveredEvent.ts | SendDeliveredEvent | Low | Simple event |
| forwardMessage.ts | ForwardMessage | Medium | Message forwarding |
| deleteMessage.ts | DeleteMessage | Low | Undo/delete |
| undo.ts | UndoMessage | Low | Undo last action |

## Batch 2: Group Management (Priority: HIGH)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| createGroup.ts | CreateGroup | Medium | Create new group |
| getAllGroups.ts | GetAllGroups | Low | List user's groups |
| addUserToGroup.ts | AddUserToGroup | Low | Add member |
| removeUserFromGroup.ts | RemoveUserFromGroup | Low | Remove member |
| leaveGroup.ts | LeaveGroup | Low | Leave group |
| changeGroupName.ts | ChangeGroupName | Low | Rename |
| changeGroupAvatar.ts | ChangeGroupAvatar | Medium | Uses upload |
| changeGroupOwner.ts | ChangeGroupOwner | Low | Transfer ownership |
| addGroupDeputy.ts | AddGroupDeputy | Low | Add admin |
| removeGroupDeputy.ts | RemoveGroupDeputy | Low | Remove admin |
| disperseGroup.ts | DisperseGroup | Low | Delete group |
| updateGroupSettings.ts | UpdateGroupSettings | Medium | Various settings |

## Batch 3: Friend Management (Priority: HIGH)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| sendFriendRequest.ts | SendFriendRequest | Low | Send request |
| acceptFriendRequest.ts | AcceptFriendRequest | Low | Accept |
| rejectFriendRequest.ts | RejectFriendRequest | Low | Reject |
| undoFriendRequest.ts | UndoFriendRequest | Low | Cancel sent |
| removeFriend.ts | RemoveFriend | Low | Unfriend |
| blockUser.ts | BlockUser | Low | Block |
| unblockUser.ts | UnblockUser | Low | Unblock |
| findUser.ts | FindUser | Medium | Search by phone/ID |
| changeFriendAlias.ts | ChangeFriendAlias | Low | Set nickname |
| removeFriendAlias.ts | RemoveFriendAlias | Low | Remove nickname |

## Batch 4: Chat Settings (Priority: MEDIUM)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| setMute.ts | SetMute | Low | Mute notifications |
| getMute.ts | GetMute | Low | Get mute status |
| setPinnedConversations.ts | SetPinnedConversations | Low | Pin chats |
| getPinConversations.ts | GetPinConversations | Low | Get pinned |
| setArchivedConversations.ts | SetArchivedConversations | Low | Archive |
| getArchivedChatList.ts | GetArchivedChatList | Low | Get archived |
| setHiddenConversations.ts | SetHiddenConversations | Low | Hide chats |
| getHiddenConversations.ts | GetHiddenConversations | Low | Get hidden |
| deleteChat.ts | DeleteChat | Low | Delete conversation |
| updateAutoDeleteChat.ts | UpdateAutoDeleteChat | Low | Auto-delete settings |
| getAutoDeleteChat.ts | GetAutoDeleteChat | Low | Get auto-delete |

## Batch 5: Account & Profile (Priority: MEDIUM)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| fetchAccountInfo.ts | FetchAccountInfo | Low | Get own info |
| updateProfile.ts | UpdateProfile | Medium | Update profile |
| changeAccountAvatar.ts | ChangeAccountAvatar | Medium | Uses upload |
| deleteAvatar.ts | DeleteAvatar | Low | Remove avatar |
| getAvatarList.ts | GetAvatarList | Low | List avatars |
| reuseAvatar.ts | ReuseAvatar | Low | Set old avatar |
| updateActiveStatus.ts | UpdateActiveStatus | Low | Online/offline |
| updateSettings.ts | UpdateSettings | Medium | App settings |
| getSettings.ts | GetSettings | Low | Get settings |
| updateLang.ts | UpdateLang | Low | Language |

## Batch 6: Polls & Reminders (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| createPoll.ts | CreatePoll | Medium | Create poll |
| getPollDetail.ts | GetPollDetail | Low | Get poll |
| votePoll.ts | VotePoll | Low | Vote |
| addPollOptions.ts | AddPollOptions | Low | Add options |
| lockPoll.ts | LockPoll | Low | Close poll |
| sharePoll.ts | SharePoll | Low | Share to chat |
| createReminder.ts | CreateReminder | Medium | Create reminder |
| editReminder.ts | EditReminder | Medium | Edit |
| removeReminder.ts | RemoveReminder | Low | Delete |
| getReminder.ts | GetReminder | Low | Get one |
| getListReminder.ts | GetListReminder | Low | List all |
| getReminderResponses.ts | GetReminderResponses | Low | Get responses |

## Batch 7: Group Advanced (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| getGroupMembersInfo.ts | GetGroupMembersInfo | Low | Member details |
| getGroupBlockedMember.ts | GetGroupBlockedMember | Low | Blocked list |
| addGroupBlockedMember.ts | AddGroupBlockedMember | Low | Block member |
| removeGroupBlockedMember.ts | RemoveGroupBlockedMember | Low | Unblock |
| getPendingGroupMembers.ts | GetPendingGroupMembers | Low | Join requests |
| reviewPendingMemberRequest.ts | ReviewPendingMemberRequest | Low | Accept/reject |
| inviteUserToGroups.ts | InviteUserToGroups | Low | Batch invite |
| enableGroupLink.ts | EnableGroupLink | Low | Enable join link |
| disableGroupLink.ts | DisableGroupLink | Low | Disable link |
| getGroupLinkDetail.ts | GetGroupLinkDetail | Low | Get link info |
| getGroupLinkInfo.ts | GetGroupLinkInfo | Low | Get by link |
| joinGroupLink.ts | JoinGroupLink | Low | Join via link |
| getGroupInviteBoxInfo.ts | GetGroupInviteBoxInfo | Medium | Invite box |
| getGroupInviteBoxList.ts | GetGroupInviteBoxList | Low | List boxes |
| deleteGroupInviteBox.ts | DeleteGroupInviteBox | Low | Delete box |
| joinGroupInviteBox.ts | JoinGroupInviteBox | Low | Join via box |

## Batch 8: Stickers & Media (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| getStickers.ts | GetStickers | Low | List packs |
| getStickersDetail.ts | GetStickersDetail | Low | Pack details |
| parseLink.ts | ParseLink | Low | URL metadata |
| getQR.ts | GetQR | Low | Generate QR |

## Batch 9: Notes & Labels (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| createNote.ts | CreateNote | Medium | Create note |
| editNote.ts | EditNote | Medium | Edit note |
| getLabels.ts | GetLabels | Low | Get labels |
| updateLabels.ts | UpdateLabels | Low | Update labels |
| addUnreadMark.ts | AddUnreadMark | Low | Mark unread |
| getUnreadMark.ts | GetUnreadMark | Low | Get marks |
| removeUnreadMark.ts | RemoveUnreadMark | Low | Remove mark |

## Batch 10: Quick Messages & Auto-Reply (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| addQuickMessage.ts | AddQuickMessage | Low | Add template |
| getQuickMessageList.ts | GetQuickMessageList | Low | List templates |
| updateQuickMessage.ts | UpdateQuickMessage | Low | Edit template |
| removeQuickMessage.ts | RemoveQuickMessage | Low | Delete |
| createAutoReply.ts | CreateAutoReply | Medium | Auto-reply |
| getAutoReplyList.ts | GetAutoReplyList | Low | List |
| updateAutoReply.ts | UpdateAutoReply | Medium | Edit |
| deleteAutoReply.ts | DeleteAutoReply | Low | Delete |

## Batch 11: Business Features (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| getBizAccount.ts | GetBizAccount | Low | Business account |
| createCatalog.ts | CreateCatalog | Medium | Product catalog |
| getCatalogList.ts | GetCatalogList | Low | List catalogs |
| updateCatalog.ts | UpdateCatalog | Medium | Edit |
| deleteCatalog.ts | DeleteCatalog | Low | Delete |
| createProductCatalog.ts | CreateProductCatalog | Medium | Add product |
| getProductCatalogList.ts | GetProductCatalogList | Low | List products |
| updateProductCatalog.ts | UpdateProductCatalog | Medium | Edit product |
| deleteProductCatalog.ts | DeleteProductCatalog | Low | Delete product |
| uploadProductPhoto.ts | UploadProductPhoto | Medium | Product images |
| sendBankCard.ts | SendBankCard | Medium | Bank card msg |

## Batch 12: Misc & Getters (Priority: LOW)
| JS File | Elixir Module | Complexity | Notes |
|---------|---------------|------------|-------|
| getAliasList.ts | GetAliasList | Low | Friend aliases |
| getFriendBoardList.ts | GetFriendBoardList | Low | Friend board |
| getFriendOnlines.ts | GetFriendOnlines | Low | Online friends |
| getFriendRecommendations.ts | GetFriendRecommendations | Low | Suggestions |
| getFriendRequestStatus.ts | GetFriendRequestStatus | Low | Request status |
| getSentFriendRequest.ts | GetSentFriendRequest | Low | Sent requests |
| getRelatedFriendGroup.ts | GetRelatedFriendGroup | Low | Mutual friends |
| getListBoard.ts | GetListBoard | Low | Board list |
| lastOnline.ts | LastOnline | Low | Last seen |
| keepAlive.ts | KeepAlive | Low | Ping server |
| blockViewFeed.ts | BlockViewFeed | Low | Block feed |
| resetHiddenConversPin.ts | ResetHiddenConversPin | Low | Reset pin |
| updateHiddenConversPin.ts | UpdateHiddenConversPin | Low | Update pin |
| sendReport.ts | SendReport | Low | Report user/msg |

## Excluded (Utility/Internal)
- custom.ts (raw API wrapper)
- getContext.ts (internal state)
- getCookie.ts (internal state)
- getOwnId.ts (internal state)
- listen.ts (WebSocket listener - already implemented as WS.Connection)
- login.ts (already implemented)
- loginQR.ts (already implemented)
- uploadAttachment.ts (already implemented)

## Implementation Notes
1. Each endpoint should follow existing patterns in lib/zca_ex/api/endpoints/
2. Use `use ZcaEx.Api.Factory` macro
3. Return `{:ok, result} | {:error, ZcaEx.Error.t()}`
4. Cross-reference JS source for exact API params and response handling
5. Create corresponding test files with unit tests
