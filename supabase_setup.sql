-- ── 유저 프로필 테이블 ──
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  avatar_url text,
  created_at timestamptz default now()
);

-- ── 게시글 테이블 ──
create table public.posts (
  id bigserial primary key,
  author_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  content text not null,
  views integer default 0,
  likes integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── 댓글 테이블 ──
create table public.comments (
  id bigserial primary key,
  post_id bigint references public.posts(id) on delete cascade not null,
  author_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  created_at timestamptz default now()
);

-- ── 좋아요 테이블 (중복 방지) ──
create table public.likes (
  user_id uuid references public.profiles(id) on delete cascade,
  post_id bigint references public.posts(id) on delete cascade,
  primary key (user_id, post_id)
);

-- ── RLS 활성화 ──
alter table public.profiles enable row level security;
alter table public.posts    enable row level security;
alter table public.comments enable row level security;
alter table public.likes    enable row level security;

-- ── 프로필 정책 ──
create policy "누구나 프로필 읽기 가능" on public.profiles for select using (true);
create policy "본인만 프로필 수정" on public.profiles for update using (auth.uid() = id);
create policy "본인만 프로필 삽입" on public.profiles for insert with check (auth.uid() = id);

-- ── 게시글 정책 ──
create policy "누구나 게시글 읽기" on public.posts for select using (true);
create policy "로그인 사용자만 글쓰기" on public.posts for insert with check (auth.uid() = author_id);
create policy "본인만 글 수정" on public.posts for update using (auth.uid() = author_id);
create policy "본인만 글 삭제" on public.posts for delete using (auth.uid() = author_id);

-- ── 댓글 정책 ──
create policy "누구나 댓글 읽기" on public.comments for select using (true);
create policy "로그인 사용자만 댓글 쓰기" on public.comments for insert with check (auth.uid() = author_id);
create policy "본인만 댓글 삭제" on public.comments for delete using (auth.uid() = author_id);

-- ── 좋아요 정책 ──
create policy "누구나 좋아요 읽기" on public.likes for select using (true);
create policy "로그인 사용자만 좋아요" on public.likes for insert with check (auth.uid() = user_id);
create policy "본인만 좋아요 취소" on public.likes for delete using (auth.uid() = user_id);

-- ── 조회수 증가 함수 (RLS 우회) ──
create or replace function increment_views(post_id bigint)
returns void language sql security definer as $$
  update public.posts set views = views + 1 where id = post_id;
$$;

-- ── 신규 가입 시 프로필 자동 생성 트리거 ──
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
