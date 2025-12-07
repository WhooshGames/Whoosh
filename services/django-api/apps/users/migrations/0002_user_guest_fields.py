# Generated migration for guest account fields

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0001_initial'),
    ]
    
    # This migration adds fields to the existing User model
    # It depends on auth migrations since User extends AbstractUser

    operations = [
        migrations.AddField(
            model_name='user',
            name='is_guest',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='user',
            name='display_name',
            field=models.CharField(blank=True, max_length=50, null=True),
        ),
        migrations.AddField(
            model_name='user',
            name='session_expires_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddIndex(
            model_name='user',
            index=models.Index(fields=['is_guest', 'session_expires_at'], name='users_is_gue_session_idx'),
        ),
    ]

