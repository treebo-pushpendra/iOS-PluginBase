//
//  MoEngagePluginBridge.swift
//  MoEngagePlugin
//
//  Created by Rakshitha on 23/06/22.
//

import Foundation
import MoEngageSDK

@objc final public class MoEngagePluginBridge: NSObject, MoEngagePluginUtils, MoEngagePluginParser, MoEngagePluginMessageDelegate {

    @objc public static let sharedInstance = MoEngagePluginBridge()
    
    private override init() {
    }
    
    @objc public func pluginInitialized(_ accountInfo: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: accountInfo),
           let messageHandler = fetchMessageQueueHandler(identifier: identifier) {
            messageHandler.flushAllMessages()
        }
    }
    
    @objc public func setPluginBridgeDelegate(_ delegate: MoEngagePluginBridgeDelegate, identifier: String) {
        if !identifier.isEmpty {
            let messageHandler = fetchMessageQueueHandler(identifier: identifier)
            messageHandler?.setBridgeDelegate(delegate: delegate)
        }
    }
    
    @objc public func setPluginBridgeDelegate(_ delegate: MoEngagePluginBridgeDelegate, payload: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: payload) {
          setPluginBridgeDelegate(delegate, identifier: identifier)
        }
    }
    
    // MARK: Analytics
    @objc public func updateSDKState(_ sdkState: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: sdkState),
           let sdkState = fetchSDKState(payload: sdkState) {
            if sdkState {
                MoEngage.sharedInstance().enableSDK(forAppID: identifier)
            } else {
                MoEngage.sharedInstance().disableSDK(forAppID: identifier)
            }
        }
    }
    
    @objc public func optOutDataTracking(_ dataTrack: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: dataTrack),
           let optOutPayload = createOptOutData(payload: dataTrack) {
            
            if optOutPayload.type == MoEngagePluginConstants.SDKState.data {
                if optOutPayload.value {
                    MOAnalytics.sharedInstance.disableDataTracking(forAppID: identifier)
                } else {
                    MOAnalytics.sharedInstance.enableDataTracking(forAppID: identifier)
                }
            }
        }
    }
    
    @objc public func setAppStatus(_ appStatus: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: appStatus),
           let appStatus = fetchAppStatus(payload: appStatus) {
            MoEngage.sharedInstance().appStatus(appStatus, forAppID: identifier)
        }
    }
    
    @objc public func setAlias(_ alias: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: alias),
           let alias = fetchAlias(payload: alias) {
            MOAnalytics.sharedInstance.setAlias(alias, forAppID: identifier)
        }
    }
    
    @objc public func setUserAttribute(_ userAttribute: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: userAttribute),
           let userAttribute = createUserAttributeData(payload: userAttribute) {
            switch userAttribute.type {
            case MoEngagePluginConstants.UserAttribute.general:
                MOAnalytics.sharedInstance.setUserAttribute(userAttribute.value, withAttributeName: userAttribute.name, forAppID: identifier)
                
            case MoEngagePluginConstants.UserAttribute.timestamp:
                if let timeStamp = userAttribute.value as? String {
                    MOAnalytics.sharedInstance.setUserAttributeISODate(timeStamp, withAttributeName: userAttribute.name, forAppID: identifier)
                }
                
            case MoEngagePluginConstants.UserAttribute.location:
                if let geoLocation = userAttribute.value as? MOGeoLocation {
                    MOAnalytics.sharedInstance.setLocation(geoLocation, withAttributeName: userAttribute.name, forAppID: identifier)
                }
                
            default:
                break
            }
        }
    }
    
    @objc public func trackEvent(_ eventAttribute: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: eventAttribute),
           let event = createEventData(payload: eventAttribute) {
            MOAnalytics.sharedInstance.trackEvent(event.name, withProperties: event.properties, forAppID: identifier)
        }
    }
    
    @objc public func resetUser(_ userAttribute: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: userAttribute) {
            MOAnalytics.sharedInstance.resetUser(forAppID: identifier)
        }
    }
    
    // MARK: InApp
    @objc public func showInApp(_ inApp: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: inApp) {
            MOInApp.sharedInstance().showInAppCampaign(forAppID: identifier)
        }
    }
    
    @objc public func getSelfHandledInApp(_ inApp: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: inApp) {
            MOInApp.sharedInstance().getSelfHandledInApp(forAppID: identifier) { [weak self] selfHandledCampaign, _
                in
                let messageHandler = self?.fetchMessageQueueHandler(identifier: identifier)
                let message = self?.selfHandledCampaignToJSON(selfHandledCampaign: selfHandledCampaign, identifier: identifier)
                messageHandler?.flushMessage(eventName: MoEngagePluginConstants.CallBackEvents.inAppSelfHandled, message: message)
            }
        }
    }
    
    @objc public func setInAppContext(_ context: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: context),
           let contexts = fetchContextData(payload: context) {
            MOInApp.sharedInstance().setCurrentInAppContexts(contexts, forAppID: identifier)
        }
    }
    
    @objc public func resetInAppContext(_ context: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: context) {
            MOInApp.sharedInstance().invalidateInAppContexts(forAppID: identifier)
        }
    }
    
    @objc public func updateSelfHandledImpression(_ inApp: [String: Any]) {
        if let identifier = fetchIdentifierFromPayload(attribute: inApp),
           let selfHandledImpressionPayload = createSelfHandledImpressionData(payload: inApp) {
            switch selfHandledImpressionPayload.impressionType {
            case MoEngagePluginConstants.InApp.impression:
                MOInApp.sharedInstance().selfHandledShown(withCampaignInfo: selfHandledImpressionPayload.selfHandledCampaign, forAppID: identifier)
            case MoEngagePluginConstants.InApp.click:
                MOInApp.sharedInstance().selfHandledClicked(withCampaignInfo: selfHandledImpressionPayload.selfHandledCampaign, forAppID: identifier)
            case MoEngagePluginConstants.InApp.dismissed:
                MOInApp.sharedInstance().selfHandledDismissed(withCampaignInfo: selfHandledImpressionPayload.selfHandledCampaign, forAppID: identifier)
            default:
                break
            }
        }
    }
    
    // MARK: Push
    @objc public func registerForPush() {
        MoEngage.sharedInstance().registerForRemoteNotification(withCategories: nil, withUserNotificationCenterDelegate: UNUserNotificationCenter.current().delegate)
    }
    
    // MARK: Other
    @objc public func validateSDKVersion() -> Bool {
        if MoEngagePluginConstants.SDKVersions.currentVersion >=  MoEngagePluginConstants.SDKVersions.minimumVersion &&  MoEngagePluginConstants.SDKVersions.currentVersion < MoEngagePluginConstants.SDKVersions.maximumVersion {
            return true
        }
        
        print("MoEngage: Plugin Bridge - Native Dependencies not integrated")
        return false
    }
}
