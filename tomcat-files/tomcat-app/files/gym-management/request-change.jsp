<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    // Restrict access: Only coaches and administrators can access this page
    if ((auth_coach_flag != 1) && (auth_admin_flag != 1) || (con == null)) {
        response.sendRedirect("/tomcat-app/gym-management/");
	if (con != null) try { con.close(); } catch (SQLException ignore) {}
        return;
    }

    String active_page = "schedule"; // Highlight schedule in navbar
    String message = null;
    String messageType = null;

    // --- PROCESS FORM SUBMISSION ---
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String group_id_str = request.getParameter("group_id");
        String request_type_str = request.getParameter("request_type");
        String target_date = request.getParameter("target_date");
        String request_text = request.getParameter("request_text");

        if (group_id_str != null && request_type_str != null && target_date != null && !target_date.isEmpty()) {
            PreparedStatement reqStmt = null;
            PreparedStatement empReqStmt = null;
            PreparedStatement grpReqStmt = null;
            ResultSet rs = null;

            try {
                con.setAutoCommit(false); // Transaction for linked requests tables

                int group_id = Integer.parseInt(group_id_str);
                int request_type = Integer.parseInt(request_type_str);

                // 1. Insert into main requests table
                String reqSql = "INSERT INTO requests (request_type, request_text, request_date, target_date) " +
                                "VALUES (?, ?, CURDATE(), ?)";
                reqStmt = con.prepareStatement(reqSql, Statement.RETURN_GENERATED_KEYS);
                reqStmt.setInt(1, request_type);
                reqStmt.setString(2, request_text);
                reqStmt.setString(3, target_date);
                reqStmt.executeUpdate();

                rs = reqStmt.getGeneratedKeys();
                int new_request_id = 0;
                if (rs.next()) {
                    new_request_id = rs.getInt(1);
                }

                // 2. Link request to coach (request_employee)
                String empReqSql = "INSERT INTO request_employee (request_id, user_id) VALUES (?, ?)";
                empReqStmt = con.prepareStatement(empReqSql);
                empReqStmt.setInt(1, new_request_id);
                empReqStmt.setInt(2, auth_user_id);
                empReqStmt.executeUpdate();

                // 3. Link request to group (request_group)
                String grpReqSql = "INSERT INTO request_group (request_id, group_id) VALUES (?, ?)";
                grpReqStmt = con.prepareStatement(grpReqSql);
                grpReqStmt.setInt(1, new_request_id);
                grpReqStmt.setInt(2, group_id);
                grpReqStmt.executeUpdate();

                con.commit();
                message = "Your request has been submitted to the administration team for review!";
                messageType = "success";
            } catch (Exception e) {
                try { con.rollback(); } catch (SQLException ignore) {}
                message = "Error submitting request: " + e.getMessage();
                messageType = "error";
            } finally {
                if (rs != null) try { rs.close(); } catch (SQLException ignore) {}
                if (reqStmt != null) try { reqStmt.close(); } catch (SQLException ignore) {}
                if (empReqStmt != null) try { empReqStmt.close(); } catch (SQLException ignore) {}
                if (grpReqStmt != null) try { grpReqStmt.close(); } catch (SQLException ignore) {}
            }
        } else {
            message = "Please fill in all required fields.";
            messageType = "error";
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Submit Schedule Request - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

    <main class="container-input">
        <div class="card">
            <div class="card-header">
                <div>
                    <h1>Submit Schedule Change Request</h1>
                    <p class="subtitle">Request to cancel, reschedule, join, or leave a gym class session.</p>
                </div>
            </div>

            <% if (message != null) { %>
                <div class="message message-<%= messageType %>">
                    <%= message %>
                </div>
            <% } %>

            <form action="request-change.jsp" method="post">
                <div class="form-row">
                    <label for="group_id">Target Class / Group *</label>
                    <select name="group_id" id="group_id" required style="width: 100%; padding: 10px; border: 1px solid var(--color-border); border-radius: 8px;">
                        <option value="">-- Select a Group --</option>
                        <%
                            PreparedStatement pstmt = null;
                            ResultSet rs = null;
                            try {
                                String sql = "SELECT g.group_id, s.sport_name, l.location_name " +
                                             "FROM groups g " +
                                             "JOIN sport_groups sg ON g.group_id = sg.group_id " +
                                             "JOIN sports s ON sg.sport_id = s.sport_id " +
                                             "JOIN location_groups lg ON g.group_id = lg.group_id " +
                                             "JOIN locations l ON lg.location_id = l.location_id " +
                                             "WHERE g.active_flag = 1";
                                pstmt = con.prepareStatement(sql);
                                rs = pstmt.executeQuery();
                                while(rs.next()) {
                        %>
                            <option value="<%= rs.getInt("group_id") %>">
                                Group #<%= rs.getInt("group_id") %> - <%= rs.getString("sport_name") %> (<%= rs.getString("location_name") %>)
                            </option>
                        <%
                                }
                            } catch (Exception e) {
                                out.println("<option value=''>Error loading groups</option>");
                            } finally {
                                if (rs != null) try { rs.close(); } catch (SQLException ignore) {}
                                if (pstmt != null) try { pstmt.close(); } catch (SQLException ignore) {}
                            }
                        %>
                    </select>
                </div>

                <div class="form-row">
                    <label for="request_type">Request Type *</label>
                    <select name="request_type" id="request_type" required style="width: 100%; padding: 10px; border: 1px solid var(--color-border); border-radius: 8px;">
                        <option value="0">Cancel Class Session</option>
                        <option value="1">Join Group as Coach</option>
                        <option value="2">Leave Group</option>
                        <option value="3">Reschedule Class</option>
                    </select>
                </div>

                <div class="form-row">
                    <label for="target_date">Target Date *</label>
                    <input type="date" name="target_date" id="target_date" required />
                </div>

                <div class="form-row">
                    <label for="request_text">Reason / Explanation *</label>
                    <textarea name="request_text" id="request_text" rows="4" required style="width: 100%; padding: 10px; border: 1px solid var(--color-border); border-radius: 8px;" placeholder="Please explain the reason for this schedule change request (e.g., medical leave, facility maintenance, conflict)..."></textarea>
                </div>

                <div style="display: flex; gap: 12px; margin-top: 20px;">
                    <button type="submit" class="btn">Submit Request</button>
                    <a href="schedule.jsp" class="btn btn-secondary">Back to Schedule</a>
                </div>
            </form>
        </div>
    </main>
<%
    try { con.close(); } catch (SQLException ignore) {}
%>
</body>
</html>
