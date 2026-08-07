<%@ page import="java.sql.*, java.util.Calendar, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
        response.sendRedirect("/tomcat-app/gym-management/");
        return;
    }

    String active_page = "groups";
    String success_message = null;
    String error_message = null;

    String group_id_param = request.getParameter("group_id");
    if (group_id_param == null || group_id_param.trim().isEmpty()) {
        response.sendRedirect("groups.jsp");
        return;
    }
    int target_group_id = Integer.parseInt(group_id_param);

    Connection conn = null;
    try {
        Context initContext = new InitialContext();
        Context envContext = (Context) initContext.lookup("java:/comp/env");
        DataSource ds = (DataSource) envContext.lookup("jdbc/GymDB");
        conn = ds.getConnection();

        // --- POST HANDLER: UPDATE GROUP ---
        if (request.getMethod().equals("POST")) {
            String sport_id = request.getParameter("sport_id");
            String location_id = request.getParameter("location_id");
            String coach_id = request.getParameter("coach_id");
            String start_date_str = request.getParameter("start_date");
            String end_date_str = request.getParameter("end_date");
            String duration = request.getParameter("duration");
            String active_flag = request.getParameter("active_flag");

            String[] days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
            String[] times = new String[7];
            for (int i = 0; i < days.length; i++) {
                String time = request.getParameter(days[i].toLowerCase() + "_time");
                times[i] = (time != null && !time.trim().isEmpty()) ? time + ":00" : null;
            }

            if (sport_id != null && location_id != null && coach_id != null && start_date_str != null) {
                conn.setAutoCommit(false);
                try {
                    // 1. Update groups table
                    String updateGroupSQL = "UPDATE `groups` SET active_flag = ?, start_date = ?, end_date = ?, duration = ?, "
                            + "Monday_time = ?, Tuesday_time = ?, Wednesday_time = ?, Thursday_time = ?, Friday_time = ?, Saturday_time = ?, Sunday_time = ? "
                            + "WHERE group_id = ?";
                    
                    PreparedStatement groupStmt = conn.prepareStatement(updateGroupSQL);
                    groupStmt.setInt(1, (active_flag != null) ? 1 : 0);
                    java.sql.Date startDate = java.sql.Date.valueOf(start_date_str);
                    groupStmt.setDate(2, startDate);
                    
                    if (end_date_str != null && !end_date_str.trim().isEmpty()) {
                        groupStmt.setDate(3, java.sql.Date.valueOf(end_date_str));
                    } else {
                        groupStmt.setNull(3, java.sql.Types.DATE);
                    }
                    
                    groupStmt.setInt(4, Integer.parseInt(duration));
                    
                    for (int i = 0; i < 7; i++) {
                        if (times[i] != null) {
                            groupStmt.setTime(5 + i, java.sql.Time.valueOf(times[i]));
                        } else {
                            groupStmt.setNull(5 + i, java.sql.Types.TIME);
                        }
                    }
                    groupStmt.setInt(12, target_group_id);
                    groupStmt.executeUpdate();
                    groupStmt.close();

                    // 2. Update sport_groups mapping
                    PreparedStatement delSport = conn.prepareStatement("DELETE FROM sport_groups WHERE group_id = ?");
                    delSport.setInt(1, target_group_id);
                    delSport.executeUpdate();
                    delSport.close();

                    PreparedStatement insSport = conn.prepareStatement("INSERT INTO sport_groups (group_id, sport_id) VALUES (?, ?)");
                    insSport.setInt(1, target_group_id);
                    insSport.setInt(2, Integer.parseInt(sport_id));
                    insSport.executeUpdate();
                    insSport.close();

                    // 3. Update location_groups mapping
                    PreparedStatement delLoc = conn.prepareStatement("DELETE FROM location_groups WHERE group_id = ?");
                    delLoc.setInt(1, target_group_id);
                    delLoc.executeUpdate();
                    delLoc.close();

                    PreparedStatement insLoc = conn.prepareStatement("INSERT INTO location_groups (group_id, location_id) VALUES (?, ?)");
                    insLoc.setInt(1, target_group_id);
                    insLoc.setInt(2, Integer.parseInt(location_id));
                    insLoc.executeUpdate();
                    insLoc.close();

                    // 4. Update assigned coach for upcoming class sessions
                    PreparedStatement updateCoachStmt = conn.prepareStatement(
                        "UPDATE class_coach SET user_id = ? WHERE group_id = ? AND date >= CURDATE()"
                    );
                    updateCoachStmt.setInt(1, Integer.parseInt(coach_id));
                    updateCoachStmt.setInt(2, target_group_id);
                    updateCoachStmt.executeUpdate();
                    updateCoachStmt.close();

                    conn.commit();
                    success_message = "Group details and schedule updated successfully!";
                } catch (SQLException e) {
                    conn.rollback();
                    error_message = "Database error: " + e.getMessage();
                } finally {
                    conn.setAutoCommit(true);
                }
            }
        }

        // --- FETCH CURRENT GROUP DATA ---
        PreparedStatement fetchStmt = conn.prepareStatement(
            "SELECT g.*, sg.sport_id, lg.location_id, cc.user_id AS coach_id " +
            "FROM `groups` g " +
            "LEFT JOIN sport_groups sg ON g.group_id = sg.group_id " +
            "LEFT JOIN location_groups lg ON g.group_id = lg.group_id " +
            "LEFT JOIN class_coach cc ON g.group_id = cc.group_id AND cc.date >= CURDATE() " +
            "WHERE g.group_id = ? LIMIT 1"
        );
        fetchStmt.setInt(1, target_group_id);
        ResultSet rs = fetchStmt.executeQuery();

        if (!rs.next()) {
            rs.close();
            fetchStmt.close();
            response.sendRedirect("groups.jsp");
            return;
        }

        int current_sport_id = rs.getInt("sport_id");
        int current_location_id = rs.getInt("location_id");
        int current_coach_id = rs.getInt("coach_id");
        int current_active = rs.getInt("active_flag");
        Date current_start = rs.getDate("start_date");
        Date current_end = rs.getDate("end_date");
        int current_duration = rs.getInt("duration");

        Time[] current_times = new Time[7];
        current_times[0] = rs.getTime("Monday_time");
        current_times[1] = rs.getTime("Tuesday_time");
        current_times[2] = rs.getTime("Wednesday_time");
        current_times[3] = rs.getTime("Thursday_time");
        current_times[4] = rs.getTime("Friday_time");
        current_times[5] = rs.getTime("Saturday_time");
        current_times[6] = rs.getTime("Sunday_time");

        rs.close();
        fetchStmt.close();
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Edit Group #<%= target_group_id %> - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

    <main class="container">
        <div class="card container-input" style="max-width: 600px; margin: 2rem auto;">
            <div class="card-header">
                <h2>Edit Training Group #<%= target_group_id %></h2>
                <p class="subtitle">Modify group parameters, coach assignments, or meeting times.</p>
            </div>

            <% if (success_message != null) { %>
                <div class="message message-success" style="color: green; margin-bottom: 1rem;"><%= success_message %></div>
            <% } else if (error_message != null) { %>
                <div class="message message-error" style="color: red; margin-bottom: 1rem;"><%= error_message %></div>
            <% } %>

            <form action="edit-group.jsp?group_id=<%= target_group_id %>" method="post">
                <div class="form-row">
                    <input type="checkbox" id="active_flag" name="active_flag" value="1" <%= current_active == 1 ? "checked" : "" %> />
                    <label class="check" for="active_flag">Active Group</label>
                </div>

                <!-- Sport -->
                <div class="form-row">
                    <label for="sport_id">Sport Type *</label>
                    <select id="sport_id" name="sport_id" required style="width: 100%; padding: 8px;">
                        <%
                            Statement sStmt = conn.createStatement();
                            ResultSet sRs = sStmt.executeQuery("SELECT sport_id, sport_name FROM sports ORDER BY sport_name");
                            while(sRs.next()) {
                                int sid = sRs.getInt("sport_id");
                        %>
                            <option value="<%= sid %>" <%= (sid == current_sport_id) ? "selected" : "" %>><%= sRs.getString("sport_name") %></option>
                        <%  } sRs.close(); sStmt.close(); %>
                    </select>
                </div>

                <!-- Location -->
                <div class="form-row">
                    <label for="location_id">Location *</label>
                    <select id="location_id" name="location_id" required style="width: 100%; padding: 8px;">
                        <%
                            Statement lStmt = conn.createStatement();
                            ResultSet lRs = lStmt.executeQuery("SELECT location_id, location_name FROM locations ORDER BY location_name");
                            while(lRs.next()) {
                                int lid = lRs.getInt("location_id");
                        %>
                            <option value="<%= lid %>" <%= (lid == current_location_id) ? "selected" : "" %>><%= lRs.getString("location_name") %></option>
                        <%  } lRs.close(); lStmt.close(); %>
                    </select>
                </div>

                <!-- Coach -->
                <div class="form-row">
                    <label for="coach_id">Assigned Coach *</label>
                    <select id="coach_id" name="coach_id" required style="width: 100%; padding: 8px;">
                        <%
                            Statement cStmt = conn.createStatement();
                            ResultSet cRs = cStmt.executeQuery(
                                "SELECT u.user_id, u.first_name, u.last_name FROM users u " +
                                "JOIN employees e ON u.user_id = e.user_id WHERE e.coach_flag = 1 ORDER BY u.first_name"
                            );
                            while(cRs.next()) {
                                int cid = cRs.getInt("user_id");
                        %>
                            <option value="<%= cid %>" <%= (cid == current_coach_id) ? "selected" : "" %>><%= cRs.getString("first_name") %> <%= cRs.getString("last_name") %></option>
                        <%  } cRs.close(); cStmt.close(); %>
                    </select>
                </div>

                <!-- Dates & Duration -->
                <div class="form-row">
                    <label for="start_date">Start Date *</label>
                    <input id="start_date" name="start_date" type="date" value="<%= current_start %>" required />
                    
                    <label for="end_date">End Date (Optional)</label>
                    <input id="end_date" name="end_date" type="date" value="<%= current_end != null ? current_end : "" %>" />
                </div>

                <div class="form-row">
                    <label for="duration">Duration (Minutes) *</label>
                    <input id="duration" name="duration" type="number" min="15" step="15" value="<%= current_duration %>" required />
                </div>

                <hr style="margin: 20px 0; border-top: 1px solid var(--color-border);" />

                <!-- Weekly Schedule -->
                <h3>Weekly Schedule</h3>
                <p class="subtitle" style="margin-bottom: 15px;">Clear time field to remove group session for that day.</p>

                <% String[] formDays = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}; 
                   for(int i = 0; i < 7; i++) { 
                       String timeVal = (current_times[i] != null) ? current_times[i].toString().substring(0, 5) : "";
                %>
                <div class="form-row" style="display: flex; align-items: center; justify-content: space-between;">
                    <label style="width: 100px;"><%= formDays[i] %></label>
                    <input type="time" name="<%= formDays[i].toLowerCase() %>_time" value="<%= timeVal %>" style="flex: 1;" />
                </div>
                <% } %>

                <div style="display: flex; gap: 10px; margin-top: 20px;">
                    <button type="submit" class="btn" style="flex: 1;">Save Changes</button>
                    <a href="groups.jsp" class="btn btn-secondary" style="text-align: center; line-height: 2.2rem; text-decoration: none;">Cancel</a>
                </div>
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