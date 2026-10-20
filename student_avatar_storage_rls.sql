-- Restrict student profile photo writes to the student's own row and storage folder.
create policy "Students can update own profile avatar"
  on public.students for update to authenticated
  using (auth_user_id = (select auth.uid()))
  with check (auth_user_id = (select auth.uid()));

create or replace function public.guard_student_self_avatar_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.auth_user_id = (select auth.uid())
     and not public.has_staff_permission('students.edit') then
    if (to_jsonb(new) - 'avatar_url' - 'updated_at') is distinct from
       (to_jsonb(old) - 'avatar_url' - 'updated_at') then
      raise exception 'Students may only update their profile photo.';
    end if;
    if new.avatar_url is not null and position(
      '/storage/v1/object/public/student-profiles/' || old.id::text || '/profile.jpg'
      in new.avatar_url
    ) = 0 then
      raise exception 'Profile photo must be stored in the student profile bucket.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists students_guard_self_avatar_update on public.students;
create trigger students_guard_self_avatar_update before update on public.students
for each row execute function public.guard_student_self_avatar_update();

create policy "Restrict student profile photo access to owner or staff"
  on storage.objects as restrictive for all to authenticated
  using (
    bucket_id <> 'student-profiles'
    or public.has_staff_permission('students.edit')
    or exists (select 1 from public.students s
      where s.id::text = (storage.foldername(storage.objects.name))[1]
        and s.auth_user_id = (select auth.uid()))
  )
  with check (
    bucket_id <> 'student-profiles'
    or public.has_staff_permission('students.edit')
    or exists (select 1 from public.students s
      where s.id::text = (storage.foldername(storage.objects.name))[1]
        and s.auth_user_id = (select auth.uid()))
  );
