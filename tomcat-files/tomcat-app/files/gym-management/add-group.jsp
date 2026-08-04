<%@ page import="java.sql.*, java.util.Calendar, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
        response.sendRedirect("/tomcat-app/gym-management/");
        return;
    }

    String active_page = "add-group";
    String success_message = null;
    String error_message = null;

    Connection conn = null;
    try {
        Context initContext = new InitialContext();
        Context envContext = (Context) initContext.lookup("java:/comp/env");
        DataSource ds = (DataSource) envContext.lookup("jdbc/GymDB");
        conn = ds.getConnection();

        if (request.getMethod().equals("POST")) {
            String sport_id = request.getParameter("sport_id");
            String location_id = request.getParameter("location_id");
            String coach_id = request.getParameter("coach_id"); // Selected Coach
            String start_date_str = request.getParameter("start_date");
            String end_date_str = request.getParameter("end_date");
            String duration = request.getParameter("duration");
            
            // Retrieve daily schedule times (Monday=1, ..., Sunday=7)
            String[] days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
            String[] times = new String[7];
            for (int i = 0; i < days.length; i++) {
                String time = request.getParameter(days[i].toLowerCase() + "_time");
                times[i] = (time != null && !time.trim().isEmpty()) ? time + ":00" : null;
            }

            if (sport_id != null && location_id != null && coach_id != null && start_date_str != null && duration != null) {
                conn.setAutoCommit(false);
                try {
                    // 1Insert into groups table
                    String insertGroupSQL = "INSERT INTO `groups` (active_flag, start_date, end_date, duration, "
                            + "Monday_time, Tuesday_time, Wednesday_time, Thursday_time, Friday_time, Saturday_time, Sunday_time) "
                            + "VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                    
                    PreparedStatement groupStmt = conn.prepareStatement(insertGroupSQL, Statement.RETURN_GENERATED_KEYS);
                    java.sql.Date startDate = java.sql.Date.valueOf(start_date_str);
                    groupStmt.setDate(1, startDate);
                    
                    if (end_date_str != null && !end_date_str.trim().isEmpty()) {
                        groupStmt.setDate(2, java.sql.Date.valueOf(end_date_str));
                    } else {
                        groupStmt.setNull(2, java.sql.Types.DATE);
                    }
                    
                    groupStmt.setInt(3, Integer.parseInt(duration));
                    
                    for (int i = 0; i < 7; i++) {
                        if (times[i] != null) {
                            groupStmt.setTime(4 + i, java.sql.Time.valueOf(times[i]));
                        } else {
                            groupStmt.setNull(4 + i, java.sql.Types.TIME);
                        }
                    }
                    
                    groupStmt.executeUpdate();
                    ResultSet rsKeys = groupStmt.getGeneratedKeys();
                    int new_group_id = -1;
                    if (rsKeys.next()) {
                        new_group_id = rsKeys.getInt(1);
                    }
                    rsKeys.close();
                    groupStmt.close();

                    if (new_group_id != -1) {
                        // Map to sport_groups
                        PreparedStatement sportStmt = conn.prepareStatement("INSERT INTO sport_groups (group_id, sport_id) VALUES (?, ?)");
                        sportStmt.setInt(1, new_group_id);
                        sportStmt.setInt(2, Integer.parseInt(sport_id));
                        sportStmt.executeUpdate();
                        sportStmt.close();

                        // Map to location_groups
                        PreparedStatement locStmt = conn.prepareStatement("INSERT INTO location_groups (group_id, location_id) VALUES (?, ?)");
                        locStmt.setInt(1, new_group_id);
                        locStmt.setInt(2, Integer.parseInt(location_id));
                        locStmt.executeUpdate();
                        locStmt.close();

                        // Generate class_schedule, class_group, & class_coach for next 14 days
                        PreparedStatement schedStmt = conn.prepareStatement(
                            "INSERT IGNORE INTO class_schedule (group_id, date, time) VALUES (?, ?, ?)"
                        );
                        PreparedStatement classGroupStmt = conn.prepareStatement(
                            "INSERT IGNORE INTO class_group (group_id, date) VALUES (?, ?)"
                        );
                        PreparedStatement coachStmt = conn.prepareStatement(
                            "INSERT IGNORE INTO class_coach (group_id, date, user_id) VALUES (?, ?, ?)"
                        );

                        Calendar cal = Calendar.getInstance();
                        cal.setTime(startDate);
                        
                        // Generate schedule instances for up to 14 days
                        for (int dayOffset = 0; dayOffset < 14; dayOffset++) {
                            int dayOfWeek = cal.get(Calendar.DAY_OF_WEEK); // Sun=1, Mon=2, ..., Sat=7
                            int arrayIdx = (dayOfWeek == Calendar.SUNDAY) ? 6 : (dayOfWeek - 2);
                            
                            if (times[arrayIdx] != null) {
                                java.sql.Date sessionDate = new java.sql.Date(cal.getTimeInMillis());
                                java.sql.Time sessionTime = java.sql.Time.valueOf(times[arrayIdx]);

                                // class_schedule
                                schedStmt.setInt(1, new_group_id);
                                schedStmt.setDate(2, sessionDate);
                                schedStmt.setTime(3, sessionTime);
                                schedStmt.executeUpdate();

                                // class_group
                                classGroupStmt.setInt(1, new_group_id);
                                classGroupStmt.setDate(2, sessionDate);
                                classGroupStmt.executeUpdate();

                                // class_coach
                                coachStmt.setInt(1, new_group_id);
                                coachStmt.setDate(2, sessionDate);
                                coachStmt.setInt(3, Integer.parseInt(coach_id));
                                coachStmt.executeUpdate();
                            }
                            cal.add(Calendar.DAY_OF_MONTH, 1);
                        }

                        schedStmt.close();
                        classGroupStmt.close();
                        coachStmt.close();

                        conn.commit();
                        success_message = "Group and initial 2-week schedule created successfully!";
                    } else {
                        conn.rollback();
                        error_message = "Failed to retrieve new group ID.";
                    }
                } catch (SQLException e) {
                    conn.rollback();
                    error_message = "Database error: " + e.getMessage();
                } finally {
                    conn.setAutoCommit(true);
                }
            } else {
                error_message = "Please fill in all required fields.";
            }
        }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Create Group - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

    <main class="container">
        <div class="card container-input" style="max-width: 600px; margin: 2rem auto;">
            <div class="card-header">
                <h2>Create New Group</h2>
                <p class="subtitle">Assign a sport, location, coach, and weekly schedule.</p>
            </div>

            <% if (success_message != null) { %>
                <div class="message message-success" style="color: green; margin-bottom: 1rem;"><%= success_message %></div>
            <% } else if (error_message != null) { %>
                <div class="message message-error" style="color: red; margin-bottom: 1rem;"><%= error_message %></div>
            <% } %>

            <form action="add-group.jsp" method="post">
                <!-- Sport Selection -->
                <div class="form-row">
                    <label for="sport_id">Sport Type *</label>
                    <select id="sport_id" name="sport_id" required style="width: 100%; padding: 8px;">
                        <option value="">-- Select Sport --</option>
                        <%
                            Statement sStmt = conn.createStatement();
                            ResultSet sRs = sStmt.executeQuery("SELECT sport_id, sport_name FROM sports ORDER BY sport_name");
                            while(sRs.next()) {
                        %>
                            <option value="<%= sRs.getInt("sport_id") %>"><%= sRs.getString("sport_name") %></option>
                        <%  } sRs.close(); sStmt.close(); %>
                    </select>
                </div>

                <!-- Location Selection -->
                <div class="form-row">
                    <label for="location_id">Location *</label>
                    <select id="location_id" name="location_id" required style="width: 100%; padding: 8px;">
                        <option value="">-- Select Location --</option>
                        <%
                            Statement lStmt = conn.createStatement();
                            ResultSet lRs = lStmt.executeQuery("SELECT location_id, location_name FROM locations ORDER BY location_name");
                            while(lRs.next()) {
                        %>
                            <option value="<%= lRs.getInt("location_id") %>"><%= lRs.getString("location_name") %></option>
                        <%  } lRs.close(); lStmt.close(); %>
                    </select>
                </div>

                <!-- Coach Selection -->
                <div class="form-row">
                    <label for="coach_id">Assigned Coach *</label>
                    <select id="coach_id" name="coach_id" required style="width: 100%; padding: 8px;">
                        <option value="">-- Select Coach --</option>
                        <%
                            Statement cStmt = conn.createStatement();
                            ResultSet cRs = cStmt.executeQuery(
                                "SELECT u.user_id, u.first_name, u.last_name FROM users u " +
                                "JOIN employees e ON u.user_id = e.user_id " +
                                "WHERE e.coach_flag = 1 ORDER BY u.first_name, u.last_name"
                            );
                            while(cRs.next()) {
                        %>
                            <option value="<%= cRs.getInt("user_id") %>"><%= cRs.getString("first_name") %> <%= cRs.getString("last_name") %></option>
                        <%  } cRs.close(); cStmt.close(); %>
                    </select>
                </div>

                <!-- Dates & Duration -->
                <div class="form-row">
                    <label for="start_date">Start Date *</label>
                    <input id="start_date" name="start_date" type="date" required />
                    
                    <label for="end_date">End Date (Optional)</label>
                    <input id="end_date" name="end_date" type="date" />
                </div>

                <div class="form-row">
                    <label for="duration">Duration (Minutes) *</label>
                    <input id="duration" name="duration" type="number" min="15" step="15" value="60" required />
                </div>

                <hr style="margin: 20px 0; border-top: 1px solid var(--color-border);" />

                <!-- Weekly Schedule -->
                <h3>Weekly Schedule</h3>
                <p class="subtitle" style="margin-bottom: 15px;">Leave blank if the group does not meet on that day.</p>

                <% String[] formDays = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}; 
                   for(String day : formDays) { %>
                <div class="form-row" style="display: flex; align-items: center; justify-content: space-between;">
                    <label style="width: 100px;"><%= day %></label>
                    <input type="time" name="<%= day.toLowerCase() %>_time" style="flex: 1;" />
                </div>
                <% } %>

                <button type="submit" class="btn" style="width: 100%; margin-top: 20px;">Create Group</button>
            </form>
        </div>
    </main>
<%
    } catch (Exception e) {
        out.println("<p>System error: " + e.getMessage() + "</p>");
    } finally {
        if (conn != null) try { conn.close(); } catch (SQLException ignore) {}
    }
%>
</body>
</html>