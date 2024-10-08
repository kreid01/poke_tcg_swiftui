import Apollo
import SwiftUI
import ChatAPI

class ChatViewModel : ObservableObject {
    @Published var messages = [GetChannelQuery.Data.Channel.Channel.Message]()
    @Published var notificationMessage: String?
    @Published var lastConnection:  MessagesQuery.Data.Message?
    @Published var activeRequest: Cancellable?
    @Published var hasMoreMessage: Bool?
    var activeSubscription: Cancellable?
    @State private var _channelId: String
    
    init(channelId: String) {
        _channelId = channelId;
    }
    
    func startSubscription() {
        activeSubscription = Network.shared.apollo.subscribe(subscription: ChannelSubscription(id : _channelId)) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .success(let graphQLResult):
                if let chatMessages = graphQLResult.data?.messages {
                    let nonOptionalMessages = chatMessages.compactMap {$0 }
                        .map{self.convertSubscriptionMessageToChannelMessage($0)}
                        .compactMap{$0}
                        .reversed()
                    self.messages.insert(contentsOf:nonOptionalMessages, at: 0)
                    self.messages = self.messages.removingDuplicatesById()
                }

                if let errors = graphQLResult.errors {
                    print(errors)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func convertSubscriptionMessageToChannelMessage(_ subscriptionMessage: ChannelSubscription.Data.Message) -> GetChannelQuery.Data.Channel.Channel.Message? {
        let data: [String: Any] = [
            "__typename": subscriptionMessage.__typename as Any,
            "id": subscriptionMessage.id,
            "content": subscriptionMessage.content,
            "user": subscriptionMessage.user,
            "date": subscriptionMessage.date,
            "channelId": subscriptionMessage.channelId
        ]
        do {
            return try GetChannelQuery.Data.Channel.Channel.Message(data: data)
        } catch {
            print(error)
        }
        
        return nil
    }

    
    func loadMoreMesssages(page: Int) {
        self.activeRequest = Network.shared.apollo.fetch(query: GetChannelQuery(id: _channelId, page: GraphQLNullable<Int>(integerLiteral: page), pageSize: 20)) { [weak self] result in
                guard let self = self else {
                    return
                }

                self.activeRequest = nil

                switch result {
                case .success(let graphQLResult):
                    if let channelConnection = graphQLResult.data?.channel {
                        self.messages.append(contentsOf: channelConnection.channel.messages.compactMap({ $0 }))
                        self.hasMoreMessage = channelConnection.hasMore
                    }

                    if let errors = graphQLResult.errors {
                        print(errors)
                    }
                case .failure(let error):
                    print(error)
                }
                }
    }
    
    
    func sendMessage(content: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentDate = Date()
        let dateString = dateFormatter.string(from: currentDate)
        let input = MessageInput(content: content, user: "Me", date: dateString, channelId: Int(_channelId)!)
        
        Network.shared.apollo.perform(mutation: PostMessageMutation(input: input)) { [weak self]
            result in guard self != nil else {
                return
            }
            
            switch result {
            case .success(let graphQLResult):
                if graphQLResult.data != nil {
                    
                   }

                if graphQLResult.errors != nil {
                       print("error")
                   }
            case .failure(_):
                    print("failure")
               }
        }
    }
    

}

extension Array where Element == GetChannelQuery.Data.Channel.Channel.Message {
    func removingDuplicatesById() -> [GetChannelQuery.Data.Channel.Channel.Message] {
        var seenIds = [String]()
        var uniqueMessages = [GetChannelQuery.Data.Channel.Channel.Message ]()
        
        for message in self {
            if !seenIds.contains(message.id) {
                seenIds.append(message.id)
                uniqueMessages.append(message)
            }
        }
        
        return uniqueMessages
    }
}
