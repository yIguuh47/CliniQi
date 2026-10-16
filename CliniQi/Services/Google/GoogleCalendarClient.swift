//
//  GoogleCalendarClient.swift
//  CliniQi
//

import Foundation

/// Chamadas REST da Google Calendar API v3.
struct GoogleCalendarClient {
    let auth: GoogleAuthService

    struct CalendarEntry: Decodable, Hashable {
        let id: String
        let summary: String?
        let summaryOverride: String?
        let backgroundColor: String?
        let accessRole: String
        let primary: Bool?
        let selected: Bool?

        var title: String { summaryOverride ?? summary ?? id }
        var isWritable: Bool { accessRole == "owner" || accessRole == "writer" }
    }

    struct Event: Decodable {
        struct Moment: Decodable {
            let dateTime: String?
            let date: String?
        }

        let id: String
        let status: String?
        let summary: String?
        let description: String?
        let htmlLink: String?
        let start: Moment
        let end: Moment
    }

    private struct ListResponse<Item: Decodable>: Decodable {
        let items: [Item]?
        let nextPageToken: String?
    }

    private static let base = URL(string: "https://www.googleapis.com/calendar/v3")!

    // MARK: - Agendas

    func calendars() async throws -> [CalendarEntry] {
        let response: ListResponse<CalendarEntry> = try await send(
            path: "users/me/calendarList",
            query: [URLQueryItem(name: "minAccessRole", value: "reader")]
        )
        return response.items ?? []
    }

    // MARK: - Eventos

    func events(calendarID: String, from start: Date, to end: Date) async throws -> [Event] {
        var all: [Event] = []
        var pageToken: String?
        repeat {
            var query = [
                URLQueryItem(name: "timeMin", value: Self.rfc3339(start)),
                URLQueryItem(name: "timeMax", value: Self.rfc3339(end)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "250")
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page: ListResponse<Event> = try await send(path: "calendars/\(Self.escape(calendarID))/events", query: query)
            all += page.items ?? []
            pageToken = page.nextPageToken
        } while pageToken != nil
        return all.filter { $0.status != "cancelled" }
    }

    func insertEvent(calendarID: String, title: String, notes: String?, start: Date, end: Date) async throws -> Event {
        let timeZone = TimeZone.current.identifier
        var body: [String: Any] = [
            "summary": title,
            "start": ["dateTime": Self.rfc3339(start), "timeZone": timeZone],
            "end": ["dateTime": Self.rfc3339(end), "timeZone": timeZone],
            "reminders": ["useDefault": false, "overrides": [["method": "popup", "minutes": 60]]]
        ]
        if let notes, !notes.isEmpty { body["description"] = notes }

        return try await send(
            path: "calendars/\(Self.escape(calendarID))/events",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body)
        )
    }

    func deleteEvent(calendarID: String, eventID: String) async throws {
        let _: Empty = try await send(
            path: "calendars/\(Self.escape(calendarID))/events/\(Self.escape(eventID))",
            method: "DELETE"
        )
    }

    // MARK: - Datas

    static func date(from moment: Event.Moment) -> (date: Date, allDay: Bool)? {
        if let value = moment.dateTime {
            return parseRFC3339(value).map { ($0, false) }
        }
        if let value = moment.date {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: value).map { ($0, true) }
        }
        return nil
    }

    private static func rfc3339(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func parseRFC3339(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    // MARK: - HTTP

    private struct Empty: Decodable {}

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/@#?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func send<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        var components = URLComponents(string: Self.base.absoluteString + "/" + path)!
        if !query.isEmpty { components.queryItems = query }
        // `+` em datas com fuso precisa ir codificado.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw GoogleError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        if T.self == Empty.self || data.isEmpty {
            return try JSONDecoder().decode(T.self, from: Data("{}".utf8))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
