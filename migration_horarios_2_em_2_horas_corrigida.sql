-- Atualiza o agendamento para horários fixos de 2 em 2 horas.
-- Execute no Supabase SQL Editor se o banco já estava instalado.

create or replace function public.available_slots(
  p_date date,
  p_duration_minutes integer
)
returns table(slot time)
language plpgsql
security definer
set search_path = public
as $$
declare
  t time;
  finish time;
  now_local timestamp;
begin
  if p_date < (now() at time zone 'America/Sao_Paulo')::date then
    return;
  end if;

  now_local := now() at time zone 'America/Sao_Paulo';
  t := time '09:00';

  while t <= time '17:00' loop
    finish := t + make_interval(mins => p_duration_minutes);

    if finish <= time '20:00'
       and (
         p_date > (now() at time zone 'America/Sao_Paulo')::date
         or (p_date = (now() at time zone 'America/Sao_Paulo')::date
             and (p_date + t) > now_local)
       )
       and not exists (
         select 1
         from public.bookings b
         where b.booking_date = p_date
           and b.status in ('pending_payment', 'confirmed')
           and tsrange(
                 p_date + t,
                 p_date + finish,
                 '[)'
               ) && tsrange(
                 p_date + b.start_time,
                 p_date + b.end_time,
                 '[)'
               )
       )
    then
      slot := t;
      return next;
    end if;

    t := t + interval '2 hours';
  end loop;
end;
$$;

grant execute on function public.available_slots(date, integer)
to anon, authenticated;


create or replace function public.create_booking(
  p_customer_name text,
  p_customer_phone text,
  p_customer_email text,
  p_service_id text,
  p_booking_date date,
  p_start_time time
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.services%rowtype;
  new_id uuid;
  finish time;
begin
  select *
  into s
  from public.services
  where id = p_service_id
    and active = true;

  if not found then
    raise exception 'Serviço inválido.';
  end if;

  if length(trim(p_customer_name)) < 2
     or length(trim(p_customer_phone)) < 8 then
    raise exception 'Informe nome e telefone válidos.';
  end if;

  if p_booking_date < (now() at time zone 'America/Sao_Paulo')::date then
    raise exception 'Escolha uma data futura.';
  end if;

  if extract(epoch from (p_start_time - time '09:00'))::integer < 0
     or mod(
       extract(epoch from (p_start_time - time '09:00'))::integer,
       7200
     ) <> 0 then
    raise exception 'Escolha um dos horários disponíveis, com intervalos de 2 horas (09:00, 11:00, 13:00, 15:00 ou 17:00).';
  end if;

  finish := p_start_time + make_interval(mins => s.duration_minutes);

  if p_start_time < time '09:00' or finish > time '20:00' then
    raise exception 'Horário fora do expediente.';
  end if;

  if p_booking_date = (now() at time zone 'America/Sao_Paulo')::date
     and (p_booking_date + p_start_time)
         <= (now() at time zone 'America/Sao_Paulo') then
    raise exception 'Este horário já passou.';
  end if;

  insert into public.bookings(
    customer_name,
    customer_phone,
    customer_email,
    service_id,
    booking_date,
    start_time,
    end_time,
    total_amount,
    deposit_amount
  )
  values (
    trim(p_customer_name),
    trim(p_customer_phone),
    nullif(trim(p_customer_email), ''),
    s.id,
    p_booking_date,
    p_start_time,
    finish,
    s.price,
    round(s.price / 2, 2)
  )
  returning id into new_id;

  return new_id;

exception
  when exclusion_violation then
    raise exception 'Este horário acabou de ser reservado. Escolha outro horário.';
end;
$$;

grant execute on function public.create_booking(text, text, text, text, date, time)
to anon, authenticated;
