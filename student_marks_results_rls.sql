-- Restrictive policies keep the existing RoyalAdmins RLS policies intact,
-- but require owner access or the corresponding staff permission.
create policy "Restrict internal mark access to owner or permitted staff"
  on public.internal_marks as restrictive for all to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = internal_marks.student_id
        and s.auth_user_id = (select auth.uid())
    )
    or public.current_staff_has_permission('internal_marks.view')
    or public.current_staff_has_permission('internal_marks.edit')
  )
  with check (public.current_staff_has_permission('internal_marks.edit'));

create policy "Restrict result access to owner or permitted staff"
  on public.result_grades as restrictive for all to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = result_grades.student_id
        and s.auth_user_id = (select auth.uid())
    )
    or public.current_staff_has_permission('result.view')
    or public.current_staff_has_permission('result.edit')
  )
  with check (public.current_staff_has_permission('result.edit'));
