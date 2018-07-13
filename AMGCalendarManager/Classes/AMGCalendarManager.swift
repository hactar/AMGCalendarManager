//
//  CalendarManager.swift
//
//  Created by Albert Montserrat on 16/02/17.
//  Copyright (c) 2015 Albert Montserrat. All rights reserved.
//

import EventKit

public class AMGCalendarManager{
    public var eventStore = EKEventStore()
    
    
    public func calendarTitles(completion: (([String]?, _ error:NSError?) -> ())? = nil) {
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(nil, weakSelf.getDeniedAccessToCalendarError())
                return
            }
            
            let titles = weakSelf.eventStore.calendars(for: .event).map({ (calendar) -> String in
                return calendar.title
            })
            completion?(titles, nil)
        }
    }
    
    
    
    public func calendar(for title: String, completion: ((EKCalendar?, _ error:NSError?) -> ())? = nil) {
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(nil, weakSelf.getDeniedAccessToCalendarError())
                return
            }
            
            var foundCal = false
            for calendar in weakSelf.eventStore.calendars(for: .event) {
                if calendar.title == title {
                    completion?(calendar,nil)
                    foundCal = true
                    break
                }
            }
            if foundCal == false {
                completion?(nil, nil)
            }
            
        }
    }
    
    
    
    public func calendars(completion: (([EKCalendar]?, _ error:NSError?) -> ())? = nil) {
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(nil, weakSelf.getDeniedAccessToCalendarError())
                return
            }
            
            completion?(weakSelf.eventStore.calendars(for: .event), nil)
        }
    }
    
    
    public static let shared = AMGCalendarManager()
    
    public init(){
    }
    
    //MARK: - Authorization
    
    public func requestAuthorization(completion: @escaping (_ allowed:Bool) -> ()){
        switch EKEventStore.authorizationStatus(for: EKEntityType.event) {
        case .authorized:
            completion(true)
        case .denied:
            completion(false)
        case .notDetermined:
            var userAllowed = false
            eventStore.requestAccess(to: .event, completion: { (allowed, error) -> Void in
                userAllowed = allowed
                if userAllowed {
                    self.reset()
                    completion(userAllowed)
                } else {
                    completion(false)
                }
            })
        default:
            completion(false)
        }
    }
    
    //MARK: - Calendar
    
    public func addCalendar(title: String, commit: Bool = true, completion: ((_ error:NSError?) -> ())? = nil) {
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError())
                return
            }
            let error = weakSelf.createCalendar(title: title, commit: commit)
            completion?(error)
        }
    }
    
    public func remove(calendar: EKCalendar, commit: Bool = true, completion: ((_ error:NSError?)-> ())? = nil) {
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError())
                return
            }
            if EKEventStore.authorizationStatus(for: EKEntityType.event) == .authorized {
                do {
                    try weakSelf.eventStore.removeCalendar(calendar, commit: true)
                    completion?(nil)
                } catch let error as NSError {
                    completion?(error)
                }
            }
        }
        
    }
    
    //MARK: - New and update events
    
    public func createEvent(calendar: EKCalendar?, completion: ((_ event:EKEvent?) -> Void)?) {
        
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(nil)
                return
            }
            
            let c = calendar ?? weakSelf.eventStore.defaultCalendarForNewEvents
            let event = EKEvent(eventStore: weakSelf.eventStore)
            event.calendar = c
            completion?(event)
            return
        }
    }
    
    public func saveEvent(calendar: EKCalendar?, event: EKEvent, span: EKSpan = .thisEvent, completion: ((_ error:NSError?) -> Void)? = nil) {
        
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError())
                return
            }
            
            if !weakSelf.insertEvent(event: event, span: span) {
                completion?(weakSelf.getGeneralError())
            } else {
                completion?(nil)
            }
        }
    }
    
    //MARK: - Remove events
    
    public func removeEvent(calendar: EKCalendar?, eventId: String, completion: ((_ error:NSError?)-> ())? = nil) {
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError())
                return
            }
            weakSelf.getEvent(eventId: eventId, completion: { (error, event) in
                if let e = event {
                    if !weakSelf.deleteEvent(event: e) {
                        completion?(weakSelf.getGeneralError())
                    } else {
                        completion?(nil)
                    }
                } else {
                    completion?(weakSelf.getGeneralError())
                }
            })
        }
    }
    
    
    //MARK: - Get events
    
    public func getAllEvents(calendar: EKCalendar?, completion: ((_ error:NSError?, _ events:[EKEvent]?)-> ())?){
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError(), nil)
                return
            }
            guard let c = calendar ?? self?.eventStore.defaultCalendarForNewEvents else {
                completion?(weakSelf.getGeneralError(),nil)
                return
            }
            let range = 31536000 * 100 as TimeInterval /* 100 Years */
            var startDate = Date(timeIntervalSince1970: -range)
            let endDate = Date(timeIntervalSinceNow: range * 2) /* 200 Years */
            let four_years = 31536000 * 4 as TimeInterval /* 4 Years */
            
            var events = [EKEvent]()
            
            while startDate < endDate {
                var currentFinish = Date(timeInterval: four_years, since: startDate)
                if currentFinish > endDate {
                    currentFinish = Date(timeInterval: 0, since: endDate)
                }
                
                let pred = weakSelf.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [c])
                events.append(contentsOf: weakSelf.eventStore.events(matching: pred))
                
                startDate = Date(timeInterval: four_years + 1, since: startDate)
            }
            
            completion?(nil, events)
        }
    }
    
    public func getEvents(startDate: Date, endDate: Date, completion: ((_ error:NSError?, _ events:[EKEvent]?)-> ())?){
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError(), nil)
                return
            }
            let pred = weakSelf.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            completion?(nil, weakSelf.eventStore.events(matching: pred))
            
            
        }
    }
    
    public func getEvent(eventId: String, completion: ((_ error:NSError?, _ event:EKEvent?)-> ())?){
        requestAuthorization() { [weak self] (allowed) in
            guard let weakSelf = self else { return }
            if !allowed {
                completion?(weakSelf.getDeniedAccessToCalendarError(), nil)
                return
            }
            let event = weakSelf.eventStore.event(withIdentifier: eventId)
            completion?(nil,event)
        }
    }
    
    //MARK: - Privates
    
    private func createCalendar(title: String, commit: Bool = true, source: EKSource? = nil) -> NSError? {
        let newCalendar = self.eventStore.defaultCalendarForNewEvents!
        newCalendar.title = title
        
        // defaultCalendarForNewEvents will always return a writtable source, even when there is no iCloud support.
        newCalendar.source = source ?? self.eventStore.defaultCalendarForNewEvents?.source
        do {
            try self.eventStore.saveCalendar(newCalendar, commit: commit)
            return nil
        } catch let error as NSError {
            if source != nil {
                return error
            } else {
                for source in self.eventStore.sources {
                    if source.sourceType == .birthdays {
                        continue
                    }
                    let err = createCalendar(title: title, source: source)
                    if err == nil {
                        return nil
                    }
                }
                return error
            }
        }
    }
    
    private func insertEvent(event: EKEvent, span: EKSpan = .thisEvent, commit: Bool = true) -> Bool {
        do {
            try eventStore.save(event, span: .thisEvent, commit: commit)
            return true
        } catch {
            return false
        }
    }
    
    private func deleteEvent(event: EKEvent, commit: Bool = true) -> Bool {
        do {
            try eventStore.remove(event, span: .futureEvents, commit: commit)
            return true
        } catch {
            return false
        }
    }
    
    //MARK: - Generic
    
    public func commit() -> Bool {
        do {
            try eventStore.commit()
            return true
        } catch {
            return false
        }
    }
    
    public func reset(){
        eventStore.reset()
    }
}

extension AMGCalendarManager {
    fileprivate func getErrorForDomain(domain: String, description: String, reason: String, code: Int = 999) -> NSError {
        let userInfo = [
            NSLocalizedDescriptionKey: description,
            NSLocalizedFailureReasonErrorKey: reason
        ]
        return NSError(domain: domain, code: code, userInfo: userInfo)
    }
    
    fileprivate func getGeneralError() -> NSError {
        return getErrorForDomain(domain: "CalendarError", description: "Unknown Error", reason: "An unknown error ocurred while trying to sync your calendar. Syncing will be turned off.", code: 999)
    }
    
    fileprivate func getDeniedAccessToCalendarError() -> NSError {
        return getErrorForDomain(domain: "CalendarAuthorization", description: "Calendar access was denied", reason: "To continue syncing your calendars re-enable Calendar access for Técnico Lisboa in Settings->Privacy->Calendars.", code: 987)
    }
    
}
